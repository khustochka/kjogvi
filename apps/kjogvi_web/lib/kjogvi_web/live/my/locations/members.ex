defmodule KjogviWeb.Live.My.Locations.Members do
  @moduledoc """
  LiveView for editing the member locations of a special location.

  Holds the pending member list in `@members`; adds go through the location
  autocomplete (specials excluded — a special may not be a member), removals
  through per-row buttons. Nothing persists until Save, which replaces the
  member list via `Geo.update_special_members/3`.
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Accounts.User
  alias Kjogvi.Geo
  alias Kjogvi.Geo.Location
  alias KjogviWeb.Live.Components.LocationAutocomplete

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    location = Geo.location_by_slug_scope(socket.assigns.current_scope, slug)

    cond do
      is_nil(location) ->
        {:ok,
         socket
         |> put_flash(:error, "Location not found")
         |> redirect(to: ~p"/my/locations")}

      location.location_type != :special ->
        {:ok,
         socket
         |> put_flash(:error, "Only special locations have members")
         |> redirect(to: ~p"/my/locations/#{location.slug}")}

      not User.owns?(socket.assigns.current_scope.current_user, location) ->
        {:ok,
         socket
         |> put_flash(:error, "You can only edit your own locations")
         |> redirect(to: ~p"/my/locations/#{location.slug}")}

      true ->
        members =
          location
          |> Geo.special_member_locations()
          |> Location.Query.put_levels()

        {:ok,
         socket
         |> assign(:page_title, "Members of #{location.name_en}")
         |> assign(:location, location)
         |> assign(:members, members)}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("remove_member", %{"id" => id}, socket) do
    id = String.to_integer(id)
    {:noreply, assign(socket, :members, Enum.reject(socket.assigns.members, &(&1.id == id)))}
  end

  def handle_event("save", _params, socket) do
    scope = socket.assigns.current_scope
    member_ids = Enum.map(socket.assigns.members, & &1.id)

    case Geo.update_special_members(scope, socket.assigns.location, member_ids) do
      {:ok, location} ->
        {:noreply,
         socket
         |> put_flash(:info, "Members updated")
         |> push_navigate(to: ~p"/my/locations/#{location.slug}")}

      {:error, :forbidden} ->
        {:noreply,
         socket
         |> put_flash(:error, "You can only edit your own locations")
         |> push_navigate(to: ~p"/my/locations")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, put_flash(socket, :error, members_error(changeset))}
    end
  end

  @impl true
  def handle_info({:autocomplete_select, "member_selected", %{"result" => result}}, socket) do
    members = socket.assigns.members

    if Enum.any?(members, &(&1.id == result.id)) do
      {:noreply, socket}
    else
      {:noreply, assign(socket, :members, members ++ [result])}
    end
  end

  def handle_info({:autocomplete_clear, "member_selected", _params}, socket) do
    {:noreply, socket}
  end

  defp members_error(changeset) do
    case changeset.errors[:special_child_locations] do
      {msg, _opts} -> "Could not save members: #{msg}"
      nil -> "Could not save members"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <nav id="location-breadcrumbs" class="text-sm text-stone-500">
        <.breadcrumb_link href={~p"/my/locations"}>Locations</.breadcrumb_link>
        <span class="mx-1 text-stone-400">/</span>
        <.breadcrumb_link
          href={~p"/my/locations/#{@location.slug}"}
          phx-no-format
        >{@location.name_en}</.breadcrumb_link>
        <span class="mx-1 text-stone-400">/</span>
        <span class="text-stone-700">Members</span>
      </nav>

      <.h1>Members of {@location.name_en}</.h1>

      <div class="max-w-xl">
        <LocationAutocomplete.location_autocomplete
          id="member-search"
          label="Add member location"
          placeholder="Search locations..."
          on_select_event="member_selected"
          scope={@current_scope}
          filter={Location.Filter.for_special_members()}
          clear_on_select
          keep_focus_on_select
        />
      </div>

      <p :if={@members == []} id="no-members" class="text-sm text-stone-500">
        No member locations yet. Search above to add some.
      </p>

      <ul
        :if={@members != []}
        id="member-list"
        class="border border-stone-200 rounded-lg divide-y divide-stone-100"
      >
        <li
          :for={member <- @members}
          id={"member-#{member.id}"}
          class="flex items-center justify-between gap-2 px-4 py-2.5"
        >
          <span class="text-sm text-stone-800">{Location.long_name(:private, member)}</span>
          <button
            type="button"
            id={"remove-member-#{member.id}"}
            phx-click="remove_member"
            phx-value-id={member.id}
            title={"Remove #{member.name_en}"}
            class="inline-flex items-center gap-1 px-2 py-1 text-xs font-medium text-rose-700 bg-rose-50 hover:bg-rose-100 rounded"
          >
            Remove
          </button>
        </li>
      </ul>

      <div class="flex gap-4 pt-2">
        <button
          id="save-members-button"
          type="button"
          phx-click="save"
          phx-disable-with="Saving..."
          class="inline-flex items-center gap-2 rounded-lg bg-green-600 px-6 py-2 text-sm font-semibold text-white hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          Save
        </button>

        <.action_button navigate={~p"/my/locations/#{@location.slug}"} variant="secondary">
          Cancel
        </.action_button>
      </div>
    </div>
    """
  end
end
