defmodule KjogviWeb.Live.My.Images.Form do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Kjogvi.Media.Image

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  # defp apply_action(socket, :edit, %{"id" => id}) do
  #   book = Books.get_book!(socket.assigns.current_scope, id)

  #   socket
  #   |> assign(:page_title, "Edit Book")
  #   |> assign(:book, book)
  #   |> assign(:form, to_form(Books.change_book(socket.assigns.current_scope, book)))
  # end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Image")
    |> assign(:form, to_form(Image.changeset(%Image{}, %{})))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.h1>
      New image
    </.h1>

    <.form for={@form} action={~p"/my/images"} id="image-form" multipart>
      <CoreComponents.input field={@form[:slug]} type="text" label="Slug" />
      <CoreComponents.input field={@form[:photo]} type="file" label="Photo" />
      <footer>
        <CoreComponents.button phx-disable-with="Saving...">Save</CoreComponents.button>
        <%!-- <.button navigate={return_path(@current_scope, @return_to, @book)}>Cancel</.button> --%>
      </footer>
    </.form>
    <div></div>
    """
  end
end
