defmodule KjogviWeb.Live.Card.Show do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Kjogvi.Birding
  alias Kjogvi.Geo

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
    }
  end

  @impl true
  def handle_params(%{"id" => id}, _url, %{assigns: assigns} = socket) do
    card0 = Birding.fetch_card(assigns.current_user, id)
    obs = card0.observations |> Kjogvi.Birding.preload_taxa_and_species()
    card = %{card0 | observations: obs}

    {
      :noreply,
      socket
      |> assign(:page_title, "Card ##{card.id}")
      |> assign(:card, card)
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <CoreComponents.header>
      Card #<%= @card.id %>
      <:subtitle>
        <%= @card.observ_date %> · <%= Geo.Location.long_name(@card.location) %>

        <span :if={@card.motorless} title="Motorless">
          <.icon name="fa-solid-bicycle" />
        </span>
      </:subtitle>
    </CoreComponents.header>

    <CoreComponents.list>
      <:item title="Effort"><%= @card.effort_type %></:item>
      <:item title="Start time"><%= @card.start_time %></:item>
      <:item title="Duration">
        <%= with duration when not is_nil(duration) <- @card.duration_minutes do %>
          <%= duration %> min
        <% end %>
      </:item>
      <:item title="Distance">
        <%= with distance when not is_nil(distance) <- @card.distance_kms do %>
          <%= distance %> km
        <% end %>
      </:item>
      <:item title="Area">
        <%= with area when not is_nil(area) <- @card.area_acres do %>
          <%= area %> acres
        <% end %>
      </:item>
      <:item title="Observers">
        <%= @card.observers %>
      </:item>
    </CoreComponents.list>
    <h2 class="py-4">Notes</h2>
    <p>
      <%= @card.notes %>
    </p>
    <h2 class="py-4">Observations</h2>
    <p :if={Enum.empty?(@card.observations)}>
      This card has no observations.
    </p>
    <CoreComponents.table
      :if={!Enum.empty?(@card.observations)}
      id="observation"
      rows={@card.observations}
    >
      <:col :let={obs} label="id"><%= obs.id %></:col>
      <:col :let={obs} label="Quantity">
        <%= obs.quantity %>
        <span :if={obs.voice} title="Heard only" class="pl-2">
          <.icon name="fa-regular-eye-slash" class="h-4 w-4" />
        </span>
      </:col>
      <:col :let={obs} label="Taxon">
        <div>
          <.link href={"/taxonomy#{obs.taxon_key}"} target="_blank">
            <%= obs.taxon_key %>
          </.link>
        </div>
        <div>
          <b class="font-semibold"><%= obs.taxon.name_en %></b>
          <i><%= obs.taxon.name_sci %></i>
        </div>
      </:col>
    </CoreComponents.table>
    """
  end
end
