defmodule KjogviWeb.LifelistLive.Index do
  use KjogviWeb, :live_view

  alias Kjogvi.Birding

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(:page_title, "Lifelist")
    }
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {
      :noreply,
      socket
      |> assign(:lifelist, Birding.lifelist())
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Lifelist
    </.header>
    <p>
      Total of <%= length(@lifelist) %> taxa.
    </p>
    <table id="lifers" class="mt-11 w-full">
      <thead class="text-sm text-left leading-6 text-zinc-500">
        <tr>
          <th class="p-0 pr-6 pb-4 font-normal">&nbsp;</th>
          <th class="p-0 pr-6 pb-4 font-normal">Species</th>
          <th class="p-0 pr-6 pb-4 font-normal">Date</th>
          <th class="p-0 pr-6 pb-4 font-normal">Time</th>
          <th class="p-0 pr-6 pb-4 font-normal">Location</th>
          <th class="p-0 pr-6 pb-4 font-normal">Card</th>
        </tr>
      </thead>
      <tbody>
        <%= for {lifer, i} <- Enum.with_index(@lifelist) do %>
          <tr class="divide-y divide-zinc-100 border-t border-zinc-200 text-sm leading-6 text-zinc-700">
            <td class="p-0 py-4 pr-6 text-right"><%= i + 1 %>.</td>
            <td class="p-0 py-4 pr-6"><%= lifer.species.name_en %></td>
            <td class="p-0 py-4 pr-6"><%= lifer.observ_date %></td>
            <td class="p-0 py-4 pr-6"><%= lifer.start_time %></td>
            <td class="p-0 py-4 pr-6"><%= lifer.location.name_en %></td>
            <td class="p-0 py-4 pr-6">
              <.link navigate={~p"/cards/#{lifer.card_id}"}>
                <.icon name="hero-clipboard-document-list" class="w-[18px]" />
              </.link>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end
end
