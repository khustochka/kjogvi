defmodule KjogviWeb.AdminMenu do
  use KjogviWeb, :live_component

  require Kjogvi.Config

  import KjogviWeb.AccessComponents
  import KjogviWeb.AdminMenuComponents

  def menu(assigns) do
    ~H"""
    <.access_control user={@current_user}>
      <:guest_access>
        <.admin_menu>
          <.admin_menu_item>
            <.link href={~p"/users/log_in"} class="no-underline hover:underline">
              Log in
            </.link>
          </.admin_menu_item>

          <%= Kjogvi.Config.with_user_registration do %>
            <.admin_menu_item>
              <.link href={~p"/users/register"} class="no-underline hover:underline">
                Register
              </.link>
            </.admin_menu_item>
          <% end %>
        </.admin_menu>
      </:guest_access>
      <:logged_in>
        <.admin_menu>
          <.admin_menu_item>
            <%= @current_user.email %>
          </.admin_menu_item>
          <.admin_menu_item>
            <.link href={~p"/users/settings"} class="no-underline hover:underline">
              Settings
            </.link>
          </.admin_menu_item>
          <.admin_menu_item>
            <.link href={~p"/admin/tasks"} class="no-underline hover:underline">
              Admin
            </.link>
          </.admin_menu_item>
          <.admin_menu_item>
            <.form_as_link
              action={~p"/users/log_out"}
              method="delete"
              class="no-underline hover:underline"
            >
              Log out
            </.form_as_link>
          </.admin_menu_item>
        </.admin_menu>
      </:logged_in>
    </.access_control>
    """
  end
end
