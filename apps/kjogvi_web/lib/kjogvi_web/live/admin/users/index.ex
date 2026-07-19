defmodule KjogviWeb.Live.Admin.Users.Index do
  @moduledoc """
  Admin index of registered users: a paginated list searchable by nickname or
  display name, with the total user count and a lock marker for users whose
  login an administrator has disabled. Listing only — no show or edit yet.

  The search term lives in the URL query string so a filtered view is linkable
  and page links preserve it; `handle_params` is the single source of truth.
  """

  use KjogviWeb, :live_view

  import Scrivener.PhoenixView

  alias Kjogvi.Accounts
  alias Kjogvi.Util.Number
  alias KjogviWeb.Live.Components.Autocomplete.SearchInput

  @users_per_page 50

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Users")
     |> assign(:users_count, Accounts.count_users())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    search_term = params |> Map.get("q", "") |> String.trim()
    page = params |> Map.get("page", "1") |> String.to_integer()

    users = Accounts.list_users_for_admin(search_term, %{page: page, page_size: @users_per_page})

    {:noreply,
     socket
     |> assign(:search_term, search_term)
     |> assign(:users, users)
     |> assign(:login_disabled_ids, Accounts.login_disabled_ids(users.entries))}
  end

  @impl true
  def handle_event("filter_users", %{"value" => search_term}, socket) do
    {:noreply, push_patch(socket, to: users_path(String.trim(search_term)))}
  end

  def handle_event("clear_user_filter", _params, socket) do
    {:noreply, push_patch(socket, to: users_path(""))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex flex-wrap items-end justify-between gap-4">
        <.h1 class="mb-0!">Users</.h1>
        <div class="inline-flex items-baseline gap-2 bg-forest-600 text-white px-3 py-2 rounded-lg mb-1">
          <span id="users-count" class="text-lg font-header font-bold tracking-tight">
            {Number.delimit(@users_count)}
          </span>
          <span class="text-forest-100 text-sm font-medium">users</span>
        </div>
      </div>

      <div class="w-full">
        <SearchInput.search_input
          id="user-search"
          value={@search_term}
          placeholder="Search users by nickname or name..."
          on_search="filter_users"
          on_clear="clear_user_filter"
        />
      </div>

      <ul :if={@users.entries != []} id="users" class="space-y-2">
        <li
          :for={user <- @users.entries}
          id={"user-#{user.id}"}
          class="flex flex-wrap items-baseline gap-x-3 gap-y-1 border border-stone-200 rounded-lg px-4 py-3"
        >
          <span class="font-header font-bold text-forest-800">{user.nickname}</span>
          <span
            :if={MapSet.member?(@login_disabled_ids, user.id)}
            role="img"
            aria-label="Login disabled"
            title="Login disabled"
            class="inline-flex text-rose-500 translate-y-0.5"
          >
            <.icon name="hero-lock-closed" class="w-4 h-4" />
          </span>
          <span :if={user.display_name} class="text-stone-700">{user.display_name}</span>
          <span class="text-sm text-stone-500">{user.email}</span>
          <span
            :if={Accounts.admin?(user)}
            class="text-xs font-semibold uppercase tracking-wider text-forest-700 bg-forest-100 border border-forest-300 rounded px-1.5 py-0.5"
          >
            Admin
          </span>
          <.link
            navigate={~p"/admin/users/#{user.id}/settings"}
            class="ml-auto self-center inline-block rounded border border-forest-300 bg-forest-50 px-2 py-0.5 text-xs font-medium text-forest-700 no-underline hover:bg-forest-100"
          >Settings</.link>
        </li>
      </ul>

      <div :if={@users.entries == []} class="text-center py-8 text-stone-500">
        <.icon name="hero-users" class="w-12 h-12 mx-auto mb-4 text-stone-300" />
        <p :if={@search_term == ""} class="text-lg font-medium">No users yet</p>
        <p :if={@search_term != ""} class="text-lg font-medium">No users found</p>
      </div>

      <div :if={@users.entries != []} class="mt-6">
        {paginate(@socket, @users, paginated_users_path(@search_term), [:index], live: true)}
      </div>
    </div>
    """
  end

  # Page links carry the search term as a query param so paging preserves the
  # active search (and keeps each page linkable).
  defp paginated_users_path(search_term) do
    fn _conn, _action, page, _params ->
      query = if search_term == "", do: [], else: [q: search_term]

      case page do
        1 -> ~p"/admin/users?#{query}"
        n -> ~p"/admin/users/page/#{n}?#{query}"
      end
    end
  end

  defp users_path(""), do: ~p"/admin/users"
  defp users_path(search_term), do: ~p"/admin/users?#{[q: search_term]}"
end
