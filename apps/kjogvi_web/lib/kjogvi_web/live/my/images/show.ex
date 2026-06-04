defmodule KjogviWeb.Live.My.Images.Show do
  @moduledoc """
  Shows a single image with its metadata, download links, and any linked
  observations.
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Images
  alias Kjogvi.Images.Image
  alias Kjogvi.Repo

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    image =
      socket.assigns.current_scope.user
      |> Images.get_image!(id)
      |> Repo.preload(observations: [card: :location])

    {:ok,
     socket
     |> assign(:page_title, image.title || image.slug)
     |> assign(:image, image)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <nav id="image-breadcrumbs" class="text-sm text-stone-500 mb-4">
      <.breadcrumb_link href={~p"/my/images"}>Images</.breadcrumb_link>
      <span class="mx-1 text-stone-400">/</span>
      <span class="text-stone-700">{@image.title || @image.slug}</span>
    </nav>

    <.h1>{@image.title || @image.slug}</.h1>

    <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mt-6">
      <div class="md:col-span-2">
        <div class="rounded-xl overflow-hidden bg-stone-100">
          <img
            src={Images.url(@image, :medium)}
            alt={@image.title || @image.slug}
            class="w-full h-auto"
          />
        </div>

        <div class="mt-2 flex flex-wrap gap-3 text-xs text-stone-500" aria-label="Download sizes">
          <span>Download:</span>
          <.link
            :for={v <- ~w(original large medium small thumbnail)a}
            href={Images.url(@image, v)}
            class="text-forest-600 hover:underline"
          >
            {String.capitalize(to_string(v))}
          </.link>
        </div>
      </div>

      <div class="space-y-4">
        <div>
          <.h2 class="text-sm! uppercase tracking-wide text-stone-500!">Details</.h2>
          <dl class="mt-2 space-y-2 text-sm">
            <div>
              <dt class="text-stone-500">Slug</dt>
              <dd class="font-mono text-stone-800">{@image.slug}</dd>
            </div>
            <div :if={@image.description}>
              <dt class="text-stone-500">Description</dt>
              <dd class="text-stone-800">{@image.description}</dd>
            </div>
            <div :if={dimensions(@image)}>
              <dt class="text-stone-500">Dimensions</dt>
              <dd class="text-stone-800">{dimensions(@image)}</dd>
            </div>
            <div :if={photo_date(@image)}>
              <dt class="text-stone-500">Photo date</dt>
              <dd class="text-stone-800">{photo_date(@image)}</dd>
            </div>
            <div>
              <dt class="text-stone-500">Sort order</dt>
              <dd class="text-stone-800">{@image.sort_order}</dd>
            </div>
          </dl>
        </div>

        <div :if={@image.observations != []}>
          <.h2 class="text-sm! uppercase tracking-wide text-stone-500!">Observations</.h2>
          <ul class="mt-2 space-y-2" aria-label="Linked observations">
            <li
              :for={obs <- @image.observations}
              id={"observation-#{obs.id}"}
              class="text-sm border border-stone-200 rounded-lg p-2"
            >
              <.link navigate={~p"/my/cards/#{obs.card_id}"} class="no-underline hover:underline">
                <span class="font-medium">{obs.taxon_key}</span>
                <span class="text-stone-500 ml-1 text-xs">{obs.card.observ_date}</span>
                <span :if={obs.card.location} class="block text-stone-400 text-xs">
                  {obs.card.location.name_en}
                </span>
              </.link>
            </li>
          </ul>
        </div>

        <div class="flex flex-wrap gap-3 pt-2 border-t border-stone-200">
          <.action_button
            navigate={~p"/my/images/#{@image.id}/edit"}
            icon="hero-pencil"
            variant="secondary"
          >
            Edit
          </.action_button>
          <button
            type="button"
            phx-click="delete"
            data-confirm="Delete this image? This cannot be undone."
            class="inline-flex items-center gap-2 rounded-lg border border-rose-200 px-4 py-2 text-sm font-semibold text-rose-600 hover:bg-rose-50"
          >
            <.icon name="hero-trash" class="w-4 h-4" /> Delete
          </button>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("delete", _params, socket) do
    case Images.delete_image(socket.assigns.image) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Image deleted")
         |> push_navigate(to: ~p"/my/images")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete image")}
    end
  end

  defp dimensions(image) do
    case Image.dimensions(image) do
      {w, h} -> "#{w} × #{h}"
      nil -> nil
    end
  end

  defp photo_date(image) do
    case Image.exif_date(image) do
      %NaiveDateTime{} = naive -> Calendar.strftime(naive, "%B %-d, %Y %H:%M")
      nil -> nil
    end
  end
end
