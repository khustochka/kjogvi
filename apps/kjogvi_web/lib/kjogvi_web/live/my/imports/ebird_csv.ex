defmodule KjogviWeb.Live.My.Imports.EbirdCsv do
  @moduledoc """
  eBird CSV import live component.

  The user uploads their eBird "Download My Data" export (a `.zip` holding a
  single CSV). On submit the zip is stashed in temporary per-user storage
  (`Kjogvi.Imports.Upload`) and an exclusive Oban job
  (`Kjogvi.Jobs.Ebird.Import`, task key `{:ebird_import, user_id}`) is
  enqueued to unpack and import it. The component seeds from
  `Kjogvi.Jobs.status/2` and follows the progress/lifecycle events broadcast
  on the key's PubSub topic.
  """

  use KjogviWeb, :live_component

  alias Kjogvi.Imports.Upload
  alias Kjogvi.Jobs
  alias Kjogvi.Util.AsyncResult
  alias Kjogvi.Util.PubSubTopic

  @component_id "ebird-csv-import"

  # 100 MB — a generous ceiling for even a heavy birder's full export.
  @max_file_size 100_000_000

  def on_mount(:attach, _params, _session, socket) do
    {:cont, attach_hook(socket, :ebird_csv_import_progress, :handle_info, &handle_progress/2)}
  end

  defp handle_progress({:progress, {:ebird_import, _user_id}, status}, socket) do
    send_update(__MODULE__,
      id: @component_id,
      async_result: AsyncResult.loading(status)
    )

    {:halt, socket}
  end

  # Lifecycle events (:start / :ok / :error) carry the AsyncResult ready to be
  # assigned as-is.
  defp handle_progress({:lifecycle, _event, {:ebird_import, _user_id}, async_result}, socket) do
    send_update(__MODULE__,
      id: @component_id,
      async_result: async_result
    )

    {:halt, socket}
  end

  defp handle_progress(_msg, socket), do: {:cont, socket}

  def update(%{user: user}, socket) do
    {:ok, socket |> assign(:user, user) |> allow_upload_once() |> subscribe_once()}
  end

  def update(%{async_result: async_result}, socket) do
    {:ok,
     socket
     |> clear_flash()
     |> assign(:async_result, async_result)
     |> derive_flash()}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :ebird_zip, ref)}
  end

  def handle_event("start_import", _params, socket) do
    {:noreply, start_import(socket)}
  end

  defp start_import(%{assigns: %{user: user}} = socket) do
    case consume_zip(socket) do
      {:ok, content} ->
        {:ok, key} = Upload.store(user, :ebird, "zip", content)
        enqueue_import(socket, user, key)

      :error ->
        socket
        |> clear_flash()
        |> put_flash(:error, "Choose an eBird export (.zip) to import.")
    end
  end

  # The import job is exclusive per user, so enqueuing while one is in flight
  # returns `:already_running` rather than starting another — and the running
  # job would never read this upload. Delete the just-stored file so it isn't
  # orphaned, and tell the user an import is already running instead of
  # silently dropping their new file.
  defp enqueue_import(socket, user, key) do
    case Kjogvi.Imports.enqueue_ebird_import(user, key) do
      {:error, :already_running} ->
        Upload.delete(key)

        socket
        |> clear_flash()
        |> put_flash(:error, "An eBird import is already in progress. Wait for it to finish.")

      {:ok, _import_log} ->
        send(self(), :refresh_import_logs)

        socket
        |> clear_flash()
        |> assign(:async_result, Jobs.status(Jobs.Ebird.Import, %{user_id: user.id}))
        |> derive_flash()
    end
  end

  defp consume_zip(socket) do
    socket
    |> consume_uploaded_entries(:ebird_zip, fn %{path: path}, _entry ->
      {:ok, File.read!(path)}
    end)
    |> case do
      [content] -> {:ok, content}
      [] -> :error
    end
  end

  # Uploads live for the component's lifetime; `allow_upload` is idempotent per
  # mount but re-running it on every parent re-render would reset in-flight
  # entries, so guard it the first time the component sees its user.
  defp allow_upload_once(socket) do
    if socket.assigns[:uploads] do
      socket
    else
      allow_upload(socket, :ebird_zip,
        accept: ~w(.zip),
        max_entries: 1,
        max_file_size: @max_file_size
      )
    end
  end

  # The PubSub subscription and initial status snapshot belong to the component's
  # lifetime, not to each parent re-render. `assign_new` seeds `async_result` the
  # first time the component is updated and is a no-op thereafter, so subsequent
  # renders keep the live `async_result` maintained by the progress/lifecycle
  # pushes instead of re-subscribing and clobbering it with a staler snapshot.
  defp subscribe_once(%{assigns: %{user: user}} = socket) do
    key = {:ebird_import, user.id}

    socket
    |> assign_new(:async_result, fn ->
      Phoenix.PubSub.subscribe(Kjogvi.PubSub, PubSubTopic.for_key(key))
      Jobs.status(Jobs.Ebird.Import, %{user_id: user.id})
    end)
    |> derive_flash()
  end

  def render(assigns) do
    ~H"""
    <div>
      <.main_flash id="ebird-csv-import-flash" flash={@flash} />
      <.form
        id="ebird-csv-import-form"
        for={nil}
        phx-change="validate"
        phx-submit="start_import"
        phx-target={@myself}
      >
        <ol class="mb-4 ml-5 list-decimal space-y-1 text-sm text-stone-600">
          <li>
            Go to
            <.link
              href="https://ebird.org/downloadMyData"
              target="_blank"
              rel="noopener"
              class="text-forest-600 hover:underline"
            >https://ebird.org/downloadMyData</.link>
          </li>
          <li>Request <b>Download My Observations</b>.</li>
          <li>Wait for eBird to email you the export (this can take a while).</li>
          <li>Upload the <code>.zip</code> file from that email below.</li>
        </ol>

        <div class="mt-2 space-y-4">
          <div
            phx-drop-target={@uploads.ebird_zip.ref}
            class={[
              "border-2 border-dashed rounded-xl p-8 text-center transition-colors",
              "[&.phx-drop-target-active]:border-forest-500 [&.phx-drop-target-active]:bg-forest-100",
              if(@uploads.ebird_zip.entries == [],
                do: "border-stone-300 bg-stone-50 hover:border-forest-400",
                else: "border-forest-400 bg-forest-50"
              )
            ]}
          >
            <.live_file_input upload={@uploads.ebird_zip} class="sr-only" />

            <div
              :if={@uploads.ebird_zip.entries == []}
              class="flex flex-col items-center gap-3 text-stone-500"
            >
              <.icon name="hero-arrow-up-tray" class="w-12 h-12 text-stone-400" />
              <div>
                <label
                  for={@uploads.ebird_zip.ref}
                  class="cursor-pointer text-forest-600 hover:underline"
                >Choose a file</label>
                or drag and drop it here
              </div>
              <div class="text-xs text-stone-400">eBird export — a single .zip, up to 100 MB</div>
            </div>

            <ul :for={entry <- @uploads.ebird_zip.entries} class="flex flex-col items-center gap-3">
              <li class="inline-flex max-w-full items-center gap-2 rounded-lg border border-forest-200 bg-white px-3 py-1.5">
                <.icon name="hero-document-check" class="w-5 h-5 text-forest-600 shrink-0" />
                <span class="text-sm text-stone-700 min-w-0 break-all">{entry.client_name}</span>
                <button
                  type="button"
                  phx-click="cancel_upload"
                  phx-value-ref={entry.ref}
                  phx-target={@myself}
                  class="shrink-0 text-stone-400 hover:text-rose-600"
                  aria-label={"Remove #{entry.client_name}"}
                >
                  <.icon name="hero-x-mark" class="size-4" />
                </button>
              </li>

              <li :if={not entry.done? and entry.progress > 0} class="w-full max-w-xs">
                <div class="w-full bg-stone-200 rounded-full h-2">
                  <div
                    class="bg-forest-500 h-2 rounded-full transition-all"
                    style={"width: #{entry.progress}%"}
                  >
                  </div>
                </div>
              </li>

              <li :for={err <- upload_errors(@uploads.ebird_zip, entry)} class="text-sm text-rose-600">
                {upload_error_message(err)}
              </li>
            </ul>
          </div>

          <ul :for={err <- upload_errors(@uploads.ebird_zip)} class="text-sm text-rose-600">
            <li>{upload_error_message(err)}</li>
          </ul>

          <div>
            <%= if @async_result.loading do %>
              <.button disabled>Import</.button>
            <% else %>
              <.button>Import</.button>
            <% end %>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  defp upload_error_message(:too_large), do: "That file is too large."
  defp upload_error_message(:not_accepted), do: "Upload an eBird export (.zip)."
  defp upload_error_message(:too_many_files), do: "Upload one file at a time."
  defp upload_error_message(_), do: "Upload failed."

  defp derive_flash(%{assigns: %{async_result: async_result}} = socket) do
    cond do
      async_result.failed ->
        put_flash(
          socket,
          :error,
          "eBird import failed: " <> result_message(async_result.failed, "Server error.")
        )

      async_result.loading ->
        put_flash(socket, :info, result_message(async_result.loading, "In progress..."))

      async_result.ok? ->
        put_flash(socket, :info, result_message(async_result.result, "Success."))

      :otherwise ->
        clear_flash(socket)
    end
  end

  defp result_message(%{message: message}, _default) when not is_nil(message), do: message
  defp result_message(:timeout, _default), do: "Timeout"
  defp result_message(_other, default), do: default
end
