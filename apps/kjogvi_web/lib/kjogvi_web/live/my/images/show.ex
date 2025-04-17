defmodule KjogviWeb.Live.My.Images.Show do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Kjogvi.Media
  alias Kjogvi.Attachments.PhotoAttachment

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _uri, socket) do
    image = Media.get_image(socket.assigns.current_scope, slug)

    {
      :noreply,
      socket
      |> assign(:page_title, image.slug)
      |> assign(:image, image)
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.h1>{@image.slug}</.h1>

    <img src={PhotoAttachment.url({@image.photo, @image})} />
    """
  end
end
