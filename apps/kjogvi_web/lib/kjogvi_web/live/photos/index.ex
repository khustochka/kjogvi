defmodule KjogviWeb.Live.Photos.Index do
  @moduledoc """
  Public gallery of images from all users, newest first.
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Images

  @images_per_page 24

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Photos")
     |> assign(:container_class, "max-w-7xl")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    page =
      params
      |> Map.get("page", "1")
      |> String.to_integer()

    {images, meta} =
      Images.list_images_for_scope(
        socket.assigns.current_scope,
        %{page: page, page_size: @images_per_page}
      )

    {:noreply,
     socket
     |> assign(:page, page)
     |> assign(:image_count, length(images))
     |> assign(:images, images)
     |> assign(:meta, meta)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.h1>Photos</.h1>

      <div :if={@image_count == 0} id="photos-empty" class="text-center py-16 text-stone-500">
        <.icon name="hero-photo" class="w-16 h-16 mx-auto text-stone-300 mb-4" />
        <p class="text-lg font-medium">No photos yet</p>
      </div>

      <.pagination
        id="photos-pagination-top"
        meta={@meta}
        path={photos_path(@current_scope)}
        label="Pagination (top)"
        class="mb-2"
        anchor="photos-pagination-top"
      />

      <ul
        id={"photos-grid-p#{@meta.current_page}"}
        class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4"
        aria-label="Photo gallery"
      >
        <li :for={image <- @images} id={"photos-#{image.id}"} class="group">
          <div class="aspect-3/2 rounded-lg overflow-hidden bg-stone-100 flex items-center justify-center">
            <img
              src={Images.url(image, :thumbnail)}
              alt={image.title || image.slug}
              class="max-w-full max-h-full object-contain"
            />
          </div>
          <p class="mt-1 text-xs text-stone-600 truncate">{image.title || image.slug}</p>
        </li>
      </ul>

      <.pagination
        id="photos-pagination"
        meta={@meta}
        path={photos_path(@current_scope)}
        anchor="photos-pagination-top"
      />
    </div>
    """
  end

  # Pagination links resolve against the area's base path: the community
  # gallery under /community/photos, a user's gallery under /users/:username/photos.
  defp photos_path(%{area: :user, subject_user: %{nickname: nickname}}) do
    fn
      1 -> ~p"/users/#{nickname}/photos"
      page -> ~p"/users/#{nickname}/photos/page/#{page}"
    end
  end

  defp photos_path(%{area: :community}) do
    fn
      1 -> ~p"/community/photos"
      page -> ~p"/community/photos/page/#{page}"
    end
  end
end
