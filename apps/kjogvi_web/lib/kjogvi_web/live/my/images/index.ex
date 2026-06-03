defmodule KjogviWeb.Live.My.Images.Index do
  @moduledoc """
  Gallery of the current user's images.
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Images

  @impl true
  def mount(_params, _session, socket) do
    images = Images.list_images(socket.assigns.current_scope.user)

    {:ok,
     socket
     |> assign(:page_title, "Images")
     |> assign(:image_count, length(images))
     |> stream(:images, images)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex flex-wrap items-end justify-between gap-4">
        <.h1 class="mb-0!">Images</.h1>
        <.action_button navigate={~p"/my/images/new"} icon="hero-plus">
          Add Image
        </.action_button>
      </div>

      <div :if={@image_count == 0} id="images-empty" class="text-center py-16 text-stone-500">
        <.icon name="hero-photo" class="w-16 h-16 mx-auto text-stone-300 mb-4" />
        <p class="text-lg font-medium">No images yet</p>
        <p class="mt-1 text-sm">
          <.link navigate={~p"/my/images/new"} class="text-forest-600 hover:underline">
            Upload your first image
          </.link>
        </p>
      </div>

      <ul
        id="images-grid"
        phx-update="stream"
        class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4"
        aria-label="Image gallery"
      >
        <li :for={{dom_id, image} <- @streams.images} id={dom_id} class="group">
          <.link navigate={~p"/my/images/#{image.id}"} class="block no-underline">
            <div class="aspect-square rounded-lg overflow-hidden bg-stone-100">
              <img
                src={Images.url(image, :thumbnail)}
                alt={image.title || image.slug}
                class="w-full h-full object-cover group-hover:opacity-90 transition-opacity"
                loading="lazy"
              />
            </div>
            <p class="mt-1 text-xs text-stone-600 truncate">{image.title || image.slug}</p>
          </.link>
        </li>
      </ul>
    </div>
    """
  end
end
