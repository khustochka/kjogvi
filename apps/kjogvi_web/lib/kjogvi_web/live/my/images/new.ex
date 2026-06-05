defmodule KjogviWeb.Live.My.Images.New do
  @moduledoc """
  Upload a new image.

  The file is auto-uploaded on drop/select; a thumbnail preview then appears
  and can be replaced. The slug is prefilled from the file name and the rest of
  the metadata form (title, description, sort order) is filled in before saving.

  Observations can optionally be attached via the shared `ImageObservations`
  picker; the selection is staged in `selected_observation_ids` and linked right
  after the image is created.
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Images
  alias Kjogvi.Images.Image
  alias KjogviWeb.Live.Components.ImageObservations

  # 50 MB.
  @max_file_size 50 * 1_024 * 1_024
  @accept ~w(.jpg .jpeg .png .webp .tiff .tif .heic .heif)

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    {:ok,
     socket
     |> assign(:page_title, "Add Image")
     |> assign(:uploaded?, false)
     |> assign(:client_name, nil)
     |> assign(:client_size, nil)
     # The finished upload, consumed to a stable Plug.Upload on progress so its
     # EXIF date can be read before save; reused as the file at save time.
     # (The preview while the entry is consumed is rendered client-side from the
     # browser-held File by the ImageUploadPreview hook.)
     |> assign(:upload, nil)
     |> assign(:selected_observation_ids, [])
     |> assign(:selected_observations, [])
     # Until a file is uploaded there is no EXIF date, so seed the picker with
     # the user's most recent card date; the EXIF date replaces it on upload.
     |> assign(:observation_date, Kjogvi.Birding.last_card_date(user))
     |> assign_form(%{"sort_order" => 100})
     |> allow_upload(:image,
       accept: @accept,
       max_entries: 1,
       max_file_size: @max_file_size,
       auto_upload: true,
       progress: &handle_progress/3
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.h1>Add Image</.h1>

      <.form for={@form} id="image-form" phx-submit="save" phx-change="validate" class="space-y-6">
        <.image_drop_zone
          id="upload-drop-zone"
          upload={@uploads.image}
          uploaded?={@uploaded?}
          client_name={@client_name}
          client_size={@client_size}
          client_preview?={true}
        />

        <div :if={@uploaded?} class="space-y-4">
          <.image_metadata_fields form={@form} />

          <.live_component
            module={ImageObservations}
            id="image-observations"
            current_user={@current_scope.user}
            date={@observation_date}
            selected={@selected_observations}
          />

          <div class="flex gap-4 pt-2 border-t border-stone-200">
            <button
              type="submit"
              phx-disable-with="Saving..."
              class="inline-flex items-center gap-2 rounded-lg bg-green-600 px-6 py-2 text-sm font-semibold text-white hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Save Image
            </button>
            <.action_button navigate={~p"/my/images"} variant="secondary">Cancel</.action_button>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  defp handle_progress(:image, entry, socket) do
    # Consume the entry now (not at save) so the file is on a stable path we can
    # read EXIF from for the observation picker. The browser-rendered preview
    # doesn't depend on the server entry, so consuming here is safe.
    with true <- entry.done?,
         {:ok, plug_upload} <- consume_upload(socket) do
      params =
        current_params(socket)
        |> maybe_prefill_slug(entry.client_name)

      {:noreply,
       socket
       |> stash_upload(plug_upload)
       |> assign(:uploaded?, true)
       |> assign(:client_name, entry.client_name)
       |> assign(:client_size, entry.client_size)
       |> assign(:observation_date, observation_date(socket, plug_upload))
       |> assign_form(params)}
    else
      _ -> {:noreply, socket}
    end
  end

  # Prefer the uploaded file's EXIF capture date; fall back to the last-card
  # date the picker was seeded with when the file carries no EXIF date.
  defp observation_date(socket, plug_upload) do
    Images.exif_date_from_upload(plug_upload) || socket.assigns.observation_date
  end

  # Replace any previously stashed upload, removing its temp file first so a
  # re-pick doesn't leak the prior file.
  defp stash_upload(socket, plug_upload) do
    discard_stash(socket)
    assign(socket, :upload, plug_upload)
  end

  # Remove the stashed temp file, if any.
  defp discard_stash(socket) do
    case socket.assigns[:upload] do
      %Plug.Upload{path: path} -> File.rm(path)
      _ -> :ok
    end
  end

  @impl true
  def handle_info({:image_observations_changed, ids}, socket) do
    user = socket.assigns.current_scope.user

    {:noreply,
     socket
     |> assign(:selected_observation_ids, ids)
     |> assign(:selected_observations, Images.get_observations_for_display(user, ids))}
  end

  @impl true
  def handle_event("validate", params, socket) do
    # The file input shares this form, so `validate` also fires on upload
    # changes — before the metadata fields exist there is no "image" key.
    {:noreply, assign_form(socket, params["image"] || %{}, :validate)}
  end

  def handle_event("save", %{"image" => params}, socket) do
    user = socket.assigns.current_scope.user

    case socket.assigns.upload do
      %Plug.Upload{} = plug_upload ->
        attrs = Map.put(params, "file", plug_upload)
        result = Images.create_image(user, attrs)

        case result do
          {:ok, image} ->
            maybe_attach_observations(image, socket.assigns.selected_observation_ids)
            discard_stash(socket)

            {:noreply,
             socket
             |> assign(:upload, nil)
             |> put_flash(:info, "Image uploaded")
             |> push_navigate(to: ~p"/my/images/#{image.id}")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset))}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Please choose a file to upload")}
    end
  end

  defp maybe_attach_observations(_image, []), do: :ok

  defp maybe_attach_observations(image, ids), do: Images.attach_observations(image, ids)

  @impl true
  def terminate(_reason, socket) do
    # Drop the stashed temp file and staged preview if the user navigated away
    # without saving.
    discard_stash(socket)
  end

  # Consume the single uploaded entry into a persistent Plug.Upload. The
  # LiveView temp file is deleted as soon as the callback returns, so copy it to
  # a path waffle can still read during create_image/2.
  defp consume_upload(socket) do
    socket
    |> consume_uploaded_entries(:image, fn %{path: path}, entry ->
      ext = Path.extname(entry.client_name)
      dest = Waffle.File.generate_temporary_path(ext)
      File.cp!(path, dest)

      {:ok,
       %Plug.Upload{
         path: dest,
         filename: entry.client_name,
         content_type: entry.client_type || "application/octet-stream"
       }}
    end)
    |> case do
      [plug_upload] -> {:ok, plug_upload}
      [] -> :error
    end
  end

  defp assign_form(socket, params, action \\ nil) do
    changeset =
      %Image{}
      |> Images.change_image(params)
      |> maybe_put_action(action)

    assign(socket, :form, to_form(changeset))
  end

  defp maybe_put_action(changeset, nil), do: changeset
  defp maybe_put_action(changeset, action), do: Map.put(changeset, :action, action)

  defp current_params(%{assigns: %{form: %Phoenix.HTML.Form{params: params}}})
       when is_map(params),
       do: params

  defp current_params(_), do: %{}

  defp maybe_prefill_slug(params, client_name) do
    if params["slug"] in [nil, ""] do
      Map.put(params, "slug", slugify(client_name))
    else
      params
    end
  end

  defp slugify(filename) do
    filename
    |> Path.basename(Path.extname(filename))
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end
end
