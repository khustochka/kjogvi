defmodule KjogviWeb.NavigationComponents do
  @moduledoc """
  Components to render forms and links.
  """
  use Phoenix.Component

  attr :action, :string, required: true
  attr :method, :string, default: "post"
  attr :class, :string
  slot :inner_block, required: true

  def form_as_link(assigns) do
    ~H"""
    <form action={@action} method="post">
      <input type="hidden" name="_method" value={@method} />
      <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
      <button class={@class}>
        <%= render_slot(@inner_block) %>
      </button>
    </form>
    """
  end
end
