defmodule KjogviWeb.Live.My.Images.Index do
  @moduledoc """
  Gallery of the current user's images.
  """

  use KjogviWeb, :live_view

  import Scrivener.PhoenixView

  alias Kjogvi.Images

  @images_per_page 20

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Images")}
  end

  @impl true
  @spec handle_params(map(), any(), map()) :: {:noreply, map()}
  def handle_params(params, _uri, socket) do
    page =
      Map.get(params, "page", "1")
      |> String.to_integer()

    images =
      Images.list_images(
        socket.assigns.current_scope.user,
        %{page: page, page_size: @images_per_page}
      )

    {:noreply,
     socket
     |> assign(:page, page)
     |> assign(:image_count, length(images.entries))
     |> assign(:images, images)}
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
        class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4"
        aria-label="Image gallery"
      >
        <li :for={image <- @images} id={"images-#{image.id}"} class="group">
          <.link navigate={~p"/my/images/#{image.id}"} class="block no-underline">
            <div class="aspect-3/2 rounded-lg overflow-hidden bg-stone-100 flex items-center justify-center">
              <img
                src={Images.url(image, :thumbnail)}
                alt={image.title || image.slug}
                class="max-w-full max-h-full object-contain"
                loading="lazy"
              />
            </div>
            <p class="mt-1 text-xs text-stone-600 truncate">{image.title || image.slug}</p>
          </.link>
        </li>
      </ul>

      <div class="mt-6">
        {paginate(@socket, @images, paginated_images_path(), [:index], live: true)}
      </div>
    </div>
    """
  end

  defp paginated_images_path() do
    fn _conn, _action, page, _params ->
      case page do
        1 -> ~p"/my/images"
        n -> ~p"/my/images/page/#{n}"
      end
    end
  end
end
