defmodule KjogviWeb.Live.Admin.Imports.Index do
  @moduledoc """
  Landing page for the admin import tools. Carries the shared section nav, the
  one-click bootstrap card, and links out to each import workbench.

  The bootstrap runs as the exclusive `Kjogvi.Jobs.Bootstrap` job, so its status
  is shared across sessions: the page subscribes to the task key's PubSub topic,
  seeds from `Kjogvi.Jobs.status/2` on mount, and follows the lifecycle and
  progress events broadcast by `Kjogvi.Jobs.Runtime.Bridge` live.
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Jobs
  alias Kjogvi.Settings
  alias Kjogvi.Util.AsyncResult
  alias Kjogvi.Util.PubSubTopic

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Kjogvi.PubSub, PubSubTopic.for_key(Jobs.Bootstrap.task_key()))
    end

    {:ok,
     socket
     |> assign(:page_title, "Imports")
     |> assign(:importer, Settings.default_taxonomy_importer())
     |> assign(:bootstrap_result, Jobs.status(Jobs.Bootstrap))}
  end

  # Inserting while a run is in flight returns the existing job instead of
  # enqueuing a second one, so re-reading the status keeps the button honest.
  @impl true
  def handle_event("start_bootstrap", _params, socket) do
    {:ok, _job} = Oban.insert(Jobs.Bootstrap.new(%{}))

    {:noreply, assign(socket, :bootstrap_result, Jobs.status(Jobs.Bootstrap))}
  end

  @impl true
  def handle_info({:lifecycle, _event, _key, async_result}, socket) do
    {:noreply, assign(socket, :bootstrap_result, async_result)}
  end

  def handle_info({:progress, _key, progress}, socket) do
    {:noreply, assign(socket, :bootstrap_result, AsyncResult.loading(progress))}
  end

  defp loading?(%AsyncResult{loading: loading}), do: not is_nil(loading)

  defp status(%AsyncResult{} = async_result) do
    cond do
      async_result.failed ->
        {:error, "Bootstrap failed: #{reason_message(async_result.failed)}"}

      async_result.loading ->
        {:loading, Map.get(async_result.loading, :message, "In progress...")}

      async_result.ok? ->
        {:ok, "Bootstrap finished."}

      true ->
        nil
    end
  end

  defp reason_message(:enoent), do: "no snapshot found."
  defp reason_message(:timeout), do: "timeout."

  defp reason_message({:taxonomy_import_failed, reason}),
    do: "taxonomy import failed: #{inspect(reason)}."

  defp reason_message({dataset, reason}) when is_atom(dataset),
    do: "#{Phoenix.Naming.humanize(dataset)}: #{inspect(reason)}."

  defp reason_message(reason), do: inspect(reason)

  defp status_class({:error, _}), do: "text-red-700"
  defp status_class({:ok, _}), do: "text-green-700"
  defp status_class({:loading, _}), do: "text-slate-600"
  defp status_class(nil), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.h1>Imports</.h1>

      <section id="bootstrap" class="border border-slate-300 rounded-lg p-6">
        <.h2 class="mb-4!">Bootstrap Everything</.h2>

        <p class="text-sm text-slate-700 mb-4">
          Seeds a fresh installation in one run, in order:
        </p>
        <ol class="text-sm text-slate-700 mb-4 space-y-1 list-decimal list-inside">
          <li>Import the <strong>{@importer.name()}</strong> taxonomy (skipped if already imported).</li>
          <li>Restore common locations from the snapshot.</li>
          <li>Restore eBird locations from the snapshot.</li>
        </ol>
        <p class="text-sm text-slate-700 mb-4">
          eBird locations link to common location ids, so they are restored last.
        </p>

        <.form id="bootstrap-form" for={nil} phx-submit="start_bootstrap">
          <.button disabled={loading?(@bootstrap_result)}>
            {if loading?(@bootstrap_result), do: "Bootstrapping…", else: "Bootstrap"}
          </.button>
        </.form>

        <p
          id="bootstrap-status"
          aria-live="polite"
          class={["mt-4 text-sm", status_class(status(@bootstrap_result))]}
        >
          <%= case status(@bootstrap_result) do %>
            <% {_kind, text} -> %>
              {text}
            <% nil -> %>
          <% end %>
        </p>
      </section>

      <ul class="flex flex-wrap gap-2">
        <li>
          <.action_button navigate={~p"/admin/imports/locations"} variant="secondary">
            Location Imports
          </.action_button>
        </li>
      </ul>
    </div>
    """
  end
end
