defmodule KjogviWeb.Live.Lifelist.Index do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Kjogvi.Util
  alias Kjogvi.Birding

  alias KjogviWeb.Live.Lifelist.Presenter

  import KjogviWeb.Live.Lifelist.Components

  @all_months 1..12

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(:user, socket.assigns.main_user)
    }
  end

  @impl true
  def handle_params(params, _url, %{assigns: assigns} = socket) do
    user = assigns.user
    public_view = assigns.live_action != :private_view
    include_private = !public_view && user.id == assigns.current_user.id

    filter = build_filter(assigns.current_user, params, include_private: include_private)

    lifelist = Birding.Lifelist.generate(user, filter)

    all_years = Birding.Lifelist.years(user)

    years =
      Birding.Lifelist.years(user, Map.delete(filter, :year))
      |> then(&Util.Enum.zip_inclusion(all_years, &1))

    months =
      Birding.Lifelist.months(user, Map.delete(filter, :month))
      |> then(&Util.Enum.zip_inclusion(@all_months, &1))

    all_countries = Kjogvi.Geo.get_countries()
    country_ids = Birding.Lifelist.country_ids(user, Map.delete(filter, :location))

    locations =
      all_countries
      |> Enum.map(fn el -> {el, el.id in country_ids} end)

    {
      :noreply,
      socket
      |> assign(
        lifelist: lifelist,
        filter: filter,
        years: years,
        months: months,
        locations: locations,
        public_view: public_view
      )
      |> derive_current_path_query()
      |> derive_location_field()
      |> derive_page_header()
      |> derive_page_title()
      |> derive_robots()
    }
  end

  @impl true
  @spec render(any()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <.header font_style={header_style(assigns)}>
      {@page_header}
      <:subheader>
        <%= if @filter.motorless do %>
          Motorless
        <% else %>
          &nbsp;
        <% end %>
        <%= if @filter.exclude_heard_only do %>
          &bull; Heard only <a href="#heard-only-list">separated</a>
        <% else %>
          &nbsp;
        <% end %>
      </:subheader>
    </.header>

    <ul class="flex flex-wrap gap-x-4 gap-y-2 mt-4">
      <li class="whitespace-nowrap">
        <em :if={!@filter.exclude_heard_only} class="font-semibold not-italic">Include all</em>
        <.link
          :if={@filter.exclude_heard_only}
          patch={
            lifelist_path(%{@filter | exclude_heard_only: false}, @current_path_query,
              private_view: !@public_view
            )
          }
        >
          Include all
        </.link>
      </li>
      <li class="whitespace-nowrap">
        <em :if={@filter.exclude_heard_only} class="font-semibold not-italic">Separate heard only</em>
        <.link
          :if={!@filter.exclude_heard_only}
          patch={
            lifelist_path(%{@filter | exclude_heard_only: true}, @current_path_query,
              private_view: !@public_view
            )
          }
        >
          Separate heard only
        </.link>
      </li>
    </ul>

    <ul class="flex flex-wrap gap-x-4 gap-y-2 mt-4">
      <li class="whitespace-nowrap">
        <em :if={!@filter.motorless} class="font-semibold not-italic">Include all</em>
        <.link
          :if={@filter.motorless}
          patch={
            lifelist_path(%{@filter | motorless: false}, @current_path_query,
              private_view: !@public_view
            )
          }
        >
          Include all
        </.link>
      </li>
      <li class="whitespace-nowrap">
        <em :if={@filter.motorless} class="font-semibold not-italic">Motorless only</em>
        <.link
          :if={!@filter.motorless}
          patch={
            lifelist_path(%{@filter | motorless: true}, @current_path_query,
              private_view: !@public_view
            )
          }
        >
          Motorless only
        </.link>
      </li>
    </ul>

    <ul class="flex flex-wrap gap-x-4 gap-y-2 mt-4">
      <li class="whitespace-nowrap">
        <em :if={is_nil(@filter.year)} class="font-semibold not-italic">All years</em>
        <.link
          :if={not is_nil(@filter.year)}
          patch={
            lifelist_path(%{@filter | year: nil}, @current_path_query, private_view: !@public_view)
          }
        >
          All years
        </.link>
      </li>
      <%= for {year, active} <- @years do %>
        <li>
          <%= if @filter.year == year do %>
            <em class="font-semibold not-italic">{year}</em>
          <% else %>
            <%= if active do %>
              <.link patch={
                lifelist_path(%{@filter | year: year}, @current_path_query,
                  private_view: !@public_view
                )
              }>
                {year}
              </.link>
            <% else %>
              <span class="text-gray-500">{year}</span>
            <% end %>
          <% end %>
        </li>
      <% end %>
    </ul>

    <ul class="flex flex-wrap gap-x-4 gap-y-2 mt-4">
      <li class="whitespace-nowrap">
        <em :if={is_nil(@filter.month)} class="font-semibold not-italic">All months</em>
        <.link
          :if={not is_nil(@filter.month)}
          patch={
            lifelist_path(%{@filter | month: nil}, Keyword.delete(@current_path_query, :month),
              private_view: !@public_view
            )
          }
        >
          All months
        </.link>
      </li>
      <%= for {month, active} <- @months do %>
        <li>
          <%= if @filter.month == month do %>
            <em class="font-semibold not-italic">{Timex.month_shortname(month)}</em>
          <% else %>
            <%= if active do %>
              <.link patch={
                lifelist_path(%{@filter | month: month}, @current_path_query,
                  private_view: !@public_view
                )
              }>
                {Timex.month_shortname(month)}
              </.link>
            <% else %>
              <span class="text-gray-500">{Timex.month_shortname(month)}</span>
            <% end %>
          <% end %>
        </li>
      <% end %>
    </ul>

    <ul class="flex flex-wrap gap-x-4 gap-y-2 mt-4">
      <li class="whitespace-nowrap">
        <em :if={is_nil(@filter.location)} class="font-semibold not-italic">All countries</em>
        <.link
          :if={not is_nil(@filter.location)}
          patch={
            lifelist_path(%{@filter | location: nil}, @current_path_query,
              private_view: !@public_view
            )
          }
        >
          All countries
        </.link>
      </li>
      <%= for {location, active} <- @locations do %>
        <li>
          <%= if @filter.location == location do %>
            <em class="font-semibold not-italic">{location.name_en}</em>
          <% else %>
            <%= if active do %>
              <.link patch={
                lifelist_path(%{@filter | location: location}, @current_path_query,
                  private_view: !@public_view
                )
              }>
                {location.name_en}
              </.link>
            <% else %>
              <span class="text-gray-500">{location.name_en}</span>
            <% end %>
          <% end %>
        </li>
      <% end %>
    </ul>

    <.lifers_table
      id="lifelist-table"
      public_view={@public_view}
      lifelist={@lifelist}
      location_field={@location_field}
    />

    <%= if @filter.exclude_heard_only do %>
      <h3
        id="heard-only-list"
        class={[
          "text-2xl",
          "font-header",
          "font-semibold",
          "leading-none",
          "text-zinc-500",
          "mt-8",
          "mb-4"
        ]}
      >
        Heard only
      </h3>

      <.lifers_table
        id="lifelist-heard-only-table"
        public_view={@public_view}
        lifelist={@lifelist.extras.heard_only}
        location_field={@location_field}
      />
    <% end %>
    """
  end

  defp build_filter(user, params, include_private: _include_private) do
    KjogviWeb.Live.Lifelist.Params.to_filter(user, params)
    |> case do
      # %{filter | include_private: include_private}
      {:ok, filter} -> filter
      {:error, _} -> raise Plug.BadRequestError
    end
  end

  # Logged in user
  defp derive_current_path_query(%{assigns: %{current_user: current_user} = _assigns} = socket)
       when not is_nil(current_user) do
    # Include here params only available to logged in user
    query =
      []
      |> Keyword.reject(fn {_, val} -> !val end)

    socket
    |> assign(:current_path_query, query)
  end

  # Guest user
  defp derive_current_path_query(socket) do
    socket
    |> assign(:current_path_query, [])
  end

  defp derive_location_field(%{assigns: assigns} = socket) do
    socket
    |> assign(
      :location_field,
      if assigns.public_view do
        :public_location
      else
        :location
      end
    )
  end

  defp derive_page_header(socket) do
    socket
    |> assign(:page_header, Presenter.title(socket.assigns.filter))
  end

  defp derive_page_title(%{assigns: assigns} = socket) do
    socket
    |> assign(:page_title, assigns[:page_header] || Presenter.title(assigns.filter))
  end

  # Month lists are not indexed
  defp derive_robots(%{assigns: %{filter: %{month: month}}} = socket) when not is_nil(month) do
    socket
    |> assign(:robots, [:noindex])
  end

  # Lifelist for diff locations and world are index (# TODO: only countries)
  defp derive_robots(%{assigns: %{filter: %{year: nil}}} = socket) do
    socket
  end

  # Empty lists are not indexed
  defp derive_robots(%{assigns: %{lifelist: %{list: []}}} = socket) do
    socket
    |> assign(:robots, [:noindex])
  end

  defp derive_robots(socket) do
    socket
  end

  defp header_style(%{year: nil, location: nil}) do
    "semibold"
  end

  defp header_style(_assigns) do
    "medium"
  end
end
