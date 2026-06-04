defmodule KjogviWeb.Live.My.Images.Edit do
  @moduledoc """
  Edit an image's metadata (slug, title, description, sort order) and,
  optionally, replace the stored file.

  The metadata form saves on its own. Replacing the file is a separate action:
  drop or choose a new file, which auto-uploads and shows a preview, then
  confirm the replacement. The new file's dimensions and EXIF date are
  re-extracted; the previous stored objects are left in place (see
  `Kjogvi.Images.replace_image_file/2`).

  TODO: add an observation search field so the linked observations can be
  edited too. Images are standalone for now.
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Images

  # 50 MB.
  @max_file_size 50 * 1_024 * 1_024
  @accept ~w(.jpg .jpeg .png .webp .tiff .tif .heic .heif)

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    image = Images.get_image!(socket.assigns.current_scope.user, id)

    {:ok,
     socket
     |> assign(:page_title, "Edit Image")
     |> assign(:image, image)
     |> assign(:replacing?, false)
     |> assign(:replace_uploaded?, false)
     |> assign(:replace_name, nil)
     |> assign(:replace_size, nil)
     |> assign(:form, to_form(Images.change_image(image)))
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
    <nav id="image-breadcrumbs" class="text-sm text-stone-500 mb-4">
      <.breadcrumb_link href={~p"/my/images"}>Images</.breadcrumb_link>
      <span class="mx-1 text-stone-400">/</span>
      <.breadcrumb_link href={~p"/my/images/#{@image.id}"} phx-no-format>{@image.title || @image.slug}</.breadcrumb_link>
      <span class="mx-1 text-stone-400">/</span>
      <span class="text-stone-700">Edit</span>
    </nav>

    <.h1>Edit Image</.h1>

    <div class="mt-6 mb-6 space-y-4">
      <div
        :if={not @replacing?}
        id="current-image-panel"
        class="flex flex-col items-center gap-3 rounded-xl border border-stone-200 bg-stone-50 p-6"
      >
        <img
          src={Images.url(@image, :medium)}
          alt={@image.title || @image.slug}
          class="max-h-72 max-w-full rounded-lg object-contain shadow"
        />

        <button
          id="replace-file-button"
          type="button"
          phx-click="start_replace"
          class="inline-flex items-center gap-2 text-sm text-forest-600 hover:underline"
        >
          <.icon name="hero-arrow-path" class="w-4 h-4" /> Replace file
        </button>
      </div>

      <form
        :if={@replacing?}
        id="replace-file-form"
        phx-submit="replace"
        phx-change="validate_upload"
        class="space-y-4"
      >
        <.image_drop_zone
          id="replace-drop-zone"
          upload={@uploads.image}
          uploaded?={@replace_uploaded?}
          client_name={@replace_name}
          client_size={@replace_size}
        />

        <div class="flex gap-4">
          <button
            type="submit"
            disabled={not @replace_uploaded?}
            phx-disable-with="Replacing..."
            class="inline-flex items-center gap-2 rounded-lg bg-green-600 px-6 py-2 text-sm font-semibold text-white hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Replace File
          </button>
          <button
            type="button"
            phx-click="cancel_replace"
            class="inline-flex items-center rounded-lg border border-stone-300 px-4 py-2 text-sm font-semibold text-stone-700 hover:bg-stone-50"
          >
            Cancel
          </button>
        </div>
      </form>
    </div>

    <.form for={@form} id="image-form" phx-submit="save" phx-change="validate" class="space-y-4">
      <CoreComponents.input field={@form[:slug]} label="Slug" required />
      <CoreComponents.input field={@form[:title]} label="Title" />
      <CoreComponents.input field={@form[:description]} type="textarea" label="Description" />
      <div class="w-32">
        <CoreComponents.input field={@form[:sort_order]} type="number" label="Sort order" min="0" />
      </div>

      <div class="flex gap-4 pt-2 border-t border-stone-200">
        <button
          type="submit"
          phx-disable-with="Saving..."
          class="inline-flex items-center gap-2 rounded-lg bg-green-600 px-6 py-2 text-sm font-semibold text-white hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          Save Changes
        </button>
        <.action_button navigate={~p"/my/images/#{@image.id}"} variant="secondary">
          Cancel
        </.action_button>
      </div>
    </.form>
    """
  end

  defp handle_progress(:image, entry, socket) do
    if entry.done? do
      {:noreply,
       socket
       |> assign(:replace_uploaded?, true)
       |> assign(:replace_name, entry.client_name)
       |> assign(:replace_size, entry.client_size)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("start_replace", _params, socket) do
    {:noreply, assign(socket, :replacing?, true)}
  end

  @impl true
  def handle_event("cancel_replace", _params, socket) do
    socket =
      Enum.reduce(socket.assigns.uploads.image.entries, socket, fn entry, socket ->
        cancel_upload(socket, :image, entry.ref)
      end)

    {:noreply,
     socket
     |> assign(:replacing?, false)
     |> assign(:replace_uploaded?, false)
     |> assign(:replace_name, nil)
     |> assign(:replace_size, nil)}
  end

  @impl true
  def handle_event("validate_upload", _params, socket) do
    # The auto-uploading file input fires phx-change; nothing to validate here,
    # the upload macro handles entry errors on its own.
    {:noreply, socket}
  end

  @impl true
  def handle_event("replace", _params, socket) do
    case consume_upload(socket) do
      {:ok, plug_upload} ->
        result = Images.replace_image_file(socket.assigns.image, %{"file" => plug_upload})
        File.rm(plug_upload.path)

        case result do
          {:ok, image} ->
            {:noreply,
             socket
             |> put_flash(:info, "Image file replaced")
             |> push_navigate(to: ~p"/my/images/#{image.id}")}

          {:error, %Ecto.Changeset{}} ->
            {:noreply, put_flash(socket, :error, "Could not replace the image file")}
        end

      :error ->
        {:noreply, put_flash(socket, :error, "Please choose a file to upload")}
    end
  end

  @impl true
  def handle_event("validate", %{"image" => params}, socket) do
    changeset =
      socket.assigns.image
      |> Images.change_image(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"image" => params}, socket) do
    case Images.update_image(socket.assigns.image, params) do
      {:ok, image} ->
        {:noreply,
         socket
         |> put_flash(:info, "Image updated")
         |> push_navigate(to: ~p"/my/images/#{image.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  # Consume the single uploaded entry into a persistent Plug.Upload. The
  # LiveView temp file is deleted as soon as the callback returns, so copy it to
  # a path waffle can still read during replace_image_file/2.
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
end
