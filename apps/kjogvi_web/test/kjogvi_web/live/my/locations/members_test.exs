defmodule KjogviWeb.Live.My.Locations.MembersTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  alias Kjogvi.Geo

  setup %{conn: conn} do
    user = user_fixture()
    %{conn: login_user(conn, user), user: user}
  end

  defp add_members(special, members) do
    Kjogvi.Repo.insert_all(
      "special_locations",
      Enum.map(members, &%{parent_location_id: special.id, child_location_id: &1.id})
    )
  end

  test "renders existing members with remove buttons", %{conn: conn, user: user} do
    special = insert(:special, name_en: "My Patch", user_id: user.id)
    member1 = insert(:location, name_en: "North Park", user_id: user.id)
    member2 = insert(:location, name_en: "South Pond", user_id: user.id)
    add_members(special, [member1, member2])

    {:ok, view, _html} = live(conn, ~p"/my/locations/#{special.slug}/members")

    assert has_element?(view, "h1", "Members of My Patch")
    assert has_element?(view, "#member-#{member1.id}", "North Park")
    assert has_element?(view, "#member-#{member2.id}", "South Pond")
    assert has_element?(view, "#remove-member-#{member1.id}")
  end

  test "shows empty state when the special has no members", %{conn: conn, user: user} do
    special = insert(:special, user_id: user.id)

    {:ok, view, _html} = live(conn, ~p"/my/locations/#{special.slug}/members")

    assert has_element?(view, "#no-members")
  end

  test "redirects for a non-special location", %{conn: conn, user: user} do
    location = insert(:location, user_id: user.id)

    assert {:error, {:redirect, %{to: to}}} =
             live(conn, ~p"/my/locations/#{location.slug}/members")

    assert to == ~p"/my/locations/#{location.slug}"
  end

  test "redirects when the special belongs to another user", %{conn: conn} do
    special = insert(:special, user_id: user_fixture().id)

    assert {:error, {:redirect, %{to: to}}} =
             live(conn, ~p"/my/locations/#{special.slug}/members")

    assert to == ~p"/my/locations"
  end

  test "redirects for a common special (not owned)", %{conn: conn} do
    special = insert(:special)

    assert {:error, {:redirect, %{to: to}}} =
             live(conn, ~p"/my/locations/#{special.slug}/members")

    assert to == ~p"/my/locations/#{special.slug}"
  end

  test "adding a member and saving persists it", %{conn: conn, user: user} do
    special = insert(:special, user_id: user.id)
    member = insert(:location, name_en: "North Park", user_id: user.id)

    {:ok, view, _html} = live(conn, ~p"/my/locations/#{special.slug}/members")

    send(view.pid, {:autocomplete_select, "member_selected", %{"result" => member}})

    assert has_element?(view, "#member-#{member.id}", "North Park")

    view |> element("#save-members-button") |> render_click()

    assert_redirect(view, ~p"/my/locations/#{special.slug}")
    assert Geo.special_member_locations(special) |> Enum.map(& &1.id) == [member.id]
  end

  test "selecting an already-listed member does not duplicate it", %{conn: conn, user: user} do
    special = insert(:special, user_id: user.id)
    member = insert(:location, user_id: user.id)
    add_members(special, [member])

    {:ok, view, _html} = live(conn, ~p"/my/locations/#{special.slug}/members")

    send(view.pid, {:autocomplete_select, "member_selected", %{"result" => member}})
    _ = render(view)

    view |> element("#save-members-button") |> render_click()

    assert Geo.special_member_locations(special) |> Enum.map(& &1.id) == [member.id]
  end

  test "removing a member keeps the row visible, marked as removed", %{conn: conn, user: user} do
    special = insert(:special, user_id: user.id)
    member = insert(:location, user_id: user.id)
    add_members(special, [member])

    {:ok, view, _html} = live(conn, ~p"/my/locations/#{special.slug}/members")

    view |> element("#remove-member-#{member.id}") |> render_click()

    assert has_element?(view, "#member-#{member.id}")
    assert has_element?(view, "#restore-member-#{member.id}")
    refute has_element?(view, "#remove-member-#{member.id}")
  end

  test "removing a member and saving persists the removal", %{conn: conn, user: user} do
    special = insert(:special, user_id: user.id)
    keep = insert(:location, user_id: user.id)
    remove = insert(:location, user_id: user.id)
    add_members(special, [keep, remove])

    {:ok, view, _html} = live(conn, ~p"/my/locations/#{special.slug}/members")

    view |> element("#remove-member-#{remove.id}") |> render_click()
    view |> element("#save-members-button") |> render_click()

    assert Geo.special_member_locations(special) |> Enum.map(& &1.id) == [keep.id]
  end

  test "restoring a removed member and saving keeps it", %{conn: conn, user: user} do
    special = insert(:special, user_id: user.id)
    member = insert(:location, user_id: user.id)
    add_members(special, [member])

    {:ok, view, _html} = live(conn, ~p"/my/locations/#{special.slug}/members")

    view |> element("#remove-member-#{member.id}") |> render_click()
    view |> element("#restore-member-#{member.id}") |> render_click()

    assert has_element?(view, "#remove-member-#{member.id}")

    view |> element("#save-members-button") |> render_click()

    assert Geo.special_member_locations(special) |> Enum.map(& &1.id) == [member.id]
  end

  test "re-selecting a removed member restores it", %{conn: conn, user: user} do
    special = insert(:special, user_id: user.id)
    member = insert(:location, user_id: user.id)
    add_members(special, [member])

    {:ok, view, _html} = live(conn, ~p"/my/locations/#{special.slug}/members")

    view |> element("#remove-member-#{member.id}") |> render_click()

    send(view.pid, {:autocomplete_select, "member_selected", %{"result" => member}})
    _ = render(view)

    assert has_element?(view, "#remove-member-#{member.id}")
    refute has_element?(view, "#restore-member-#{member.id}")
  end

  test "member suggestions exclude special locations", %{conn: conn, user: user} do
    special = insert(:special, name_en: "Park Circle", user_id: user.id)
    _site = insert(:location, name_en: "Park Site", user_id: user.id)
    _other_special = insert(:special, name_en: "Park Special", user_id: user.id)

    {:ok, view, _html} = live(conn, ~p"/my/locations/#{special.slug}/members")

    html = view |> element("#member-search") |> render_keyup(%{"value" => "Park"})

    # The matched term is wrapped in highlight markup, so assert on the rest.
    assert html =~ "Site"
    refute html =~ "Special"
  end
end
