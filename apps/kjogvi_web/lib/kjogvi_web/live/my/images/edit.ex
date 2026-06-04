defmodule KjogviWeb.Live.My.Images.Edit do
  @moduledoc """
  Edit an image's metadata (slug, title, description, sort order).

  The stored file is not replaceable here — upload a new image for that.

  TODO: add an observation search field so the linked observations can be
  edited too. Images are standalone for now.
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Images

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    image = Images.get_image!(socket.assigns.current_scope.user, id)

    {:ok,
     socket
     |> assign(:page_title, "Edit Image")
     |> assign(:image, image)
     |> assign(:form, to_form(Images.change_image(image)))}
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

    <div class="mt-6 mb-6">
      <img
        src={Images.url(@image, :thumbnail)}
        alt={@image.title || @image.slug}
        class="max-h-40 rounded-lg object-contain bg-stone-100"
      />
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
end
