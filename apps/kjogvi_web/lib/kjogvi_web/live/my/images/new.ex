defmodule KjogviWeb.Live.My.Images.New do
  @moduledoc """
  Upload a new image.

  The file is auto-uploaded on drop/select; a thumbnail preview then appears
  and can be replaced. The slug is prefilled from the file name and the rest of
  the metadata form (title, description, sort order) is filled in before saving.

  TODO: add an observation search field so an image can optionally be linked to
  observations on save. Images are standalone for now.
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Images
  alias Kjogvi.Images.Image

  # 50 MB.
  @max_file_size 50 * 1_024 * 1_024
  @accept ~w(.jpg .jpeg .png .webp .tiff .tif .heic .heif)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Add Image")
     |> assign(:uploaded?, false)
     |> assign(:client_name, nil)
     |> assign(:client_size, nil)
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
        />

        <div :if={@uploaded?} class="space-y-4">
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
    if entry.done? do
      params =
        current_params(socket)
        |> maybe_prefill_slug(entry.client_name)

      {:noreply,
       socket
       |> assign(:uploaded?, true)
       |> assign(:client_name, entry.client_name)
       |> assign(:client_size, entry.client_size)
       |> assign_form(params)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("validate", params, socket) do
    # The file input shares this form, so `validate` also fires on upload
    # changes — before the metadata fields exist there is no "image" key.
    {:noreply, assign_form(socket, params["image"] || %{}, :validate)}
  end

  @impl true
  def handle_event("save", %{"image" => params}, socket) do
    user = socket.assigns.current_scope.user

    case consume_upload(socket) do
      {:ok, plug_upload} ->
        attrs = Map.put(params, "file", plug_upload)
        result = Images.create_image(user, attrs)
        File.rm(plug_upload.path)

        case result do
          {:ok, image} ->
            {:noreply,
             socket
             |> put_flash(:info, "Image uploaded")
             |> push_navigate(to: ~p"/my/images/#{image.id}")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset))}
        end

      :error ->
        {:noreply, put_flash(socket, :error, "Please choose a file to upload")}
    end
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
