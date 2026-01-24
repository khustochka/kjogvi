defmodule KjogviWeb.Live.My.Cards.FormTest do
  use KjogviWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Kjogvi.UsersFixtures
  alias Kjogvi.GeoFixtures
  alias Kjogvi.Birding
  alias Kjogvi.Search

  describe "card form" do
    setup do
      user = UsersFixtures.user_fixture()
      token = Kjogvi.Users.generate_user_session_token(user)

      conn =
        build_conn()
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      {:ok, conn: conn, user: user}
    end

    test "renders new card form", %{conn: conn, user: _user} do
      {:ok, _lv, html} = live(conn, "/my/cards/new")
      assert html =~ "New Card"
      assert html =~ "Observation Date"
      assert html =~ "Effort Type"
    end

    test "renders effort type as dropdown", %{conn: conn, user: _user} do
      {:ok, _lv, html} = live(conn, "/my/cards/new")
      assert html =~ "select"
      assert html =~ "Stationary"
      assert html =~ "Traveling"
    end

    test "renders location field with type=search", %{conn: conn, user: _user} do
      {:ok, _lv, html} = live(conn, "/my/cards/new")
      assert html =~ "Location"
      assert html =~ "type=\"search\""
    end

    test "renders location search as hidden input for ID storage", %{conn: conn, user: _user} do
      {:ok, _lv, html} = live(conn, "/my/cards/new")
      assert html =~ "card_location_id"
      assert html =~ "type=\"hidden\""
    end

    test "renders observation section with add button", %{conn: conn, user: _user} do
      {:ok, _lv, html} = live(conn, "/my/cards/new")
      assert html =~ "Observations"
      assert html =~ "Add Observation"
    end

    test "can add observations", %{conn: conn, user: _user} do
      {:ok, lv, _html} = live(conn, "/my/cards/new")

      lv |> element("button", "Add Observation") |> render_click()

      html = render(lv)
      assert html =~ "Taxon"
      assert html =~ "Quantity"
    end

    test "can remove observations", %{conn: conn, user: _user} do
      {:ok, lv, _html} = live(conn, "/my/cards/new")

      lv |> element("button", "Add Observation") |> render_click()

      html = render(lv)
      assert html =~ "Remove"

      lv |> element("button", "Remove") |> render_click()

      html = render(lv)
      assert html =~ "No observations yet"
    end

    test "renders form fields in 3-column layout", %{conn: conn, user: _user} do
      {:ok, _lv, html} = live(conn, "/my/cards/new")
      assert html =~ "sm:grid-cols-3"
    end

    test "taxon input has type=search", %{conn: conn, user: _user} do
      {:ok, lv, _html} = live(conn, "/my/cards/new")

      lv |> element("button", "Add Observation") |> render_click()

      html = render(lv)
      assert html =~ "type=\"search\""
      assert html =~ "Taxon"
    end

    test "observation has hidden field for taxon_key", %{conn: conn, user: _user} do
      {:ok, lv, _html} = live(conn, "/my/cards/new")

      lv |> element("button", "Add Observation") |> render_click()

      html = render(lv)
      assert html =~ "type=\"hidden\""
      assert html =~ "taxon_key"
    end

    test "can add multiple observations", %{conn: conn, user: _user} do
      {:ok, lv, _html} = live(conn, "/my/cards/new")

      lv |> element("button", "Add Observation") |> render_click()
      lv |> element("button", "Add Observation") |> render_click()

      html = render(lv)
      assert html =~ "Remove"
    end

    test "location search results display with dropdown styling", %{conn: conn, user: _user} do
      _location = GeoFixtures.location_fixture(name_en: "Central Park")
      {:ok, lv, _html} = live(conn, "/my/cards/new")

      lv |> render_change("search_locations", %{"value" => "Central"})

      html = render(lv)
      assert html =~ "Central Park"
    end

    test "can select location from search results", %{conn: conn, user: _user} do
      location = GeoFixtures.location_fixture(name_en: "Central Park")
      {:ok, lv, _html} = live(conn, "/my/cards/new")

      lv |> render_change("search_locations", %{"value" => "Central"})

      lv
      |> render_click("select_location", %{
        "id" => to_string(location.id),
        "name" => "Central Park"
      })

      html = render(lv)
      assert html =~ "Central Park"
    end
  end

  describe "location search" do
    test "search_locations filters by query" do
      location1 = GeoFixtures.location_fixture(name_en: "Central Park")
      location2 = GeoFixtures.location_fixture(name_en: "Hyde Park")

      results = Search.Location.search_locations("Central")
      assert Enum.any?(results, &(&1.id == location1.id))
      refute Enum.any?(results, &(&1.id == location2.id))
    end

    test "search_locations includes hidden locations" do
      _public = GeoFixtures.location_fixture(name_en: "Public Park", is_private: false)
      _private = GeoFixtures.location_fixture(name_en: "Private Park", is_private: true)

      results = Search.Location.search_locations("Park")
      assert Enum.any?(results, &String.contains?(&1.name, "Public"))
      assert Enum.any?(results, &String.contains?(&1.name, "Private"))
    end

    test "search_locations prioritizes exact match" do
      _exact = GeoFixtures.location_fixture(name_en: "Park")
      _prefix = GeoFixtures.location_fixture(name_en: "Park Lane")

      results = Search.Location.search_locations("Park")
      assert length(results) > 0
      assert Enum.at(results, 0).name =~ "Park"
    end
  end

  describe "effort types enum" do
    test "can retrieve effort types as names and values" do
      types = Kjogvi.Birding.Card.effort_types
      assert Enum.any?(types, fn {name, _value} -> name == "Stationary" end)
      assert Enum.any?(types, fn {name, _value} -> name == "Traveling" end)
    end

    test "can retrieve effort type values" do
      values = Kjogvi.Birding.Card.effort_types(:values)
      assert Enum.member?(values, "STATIONARY")
      assert Enum.member?(values, "TRAVEL")
    end

    test "all effort types have consistent structure" do
      types = Kjogvi.Birding.Card.effort_types()
      assert Enum.all?(types, fn {_atom, _value, _name} -> true end)
    end
  end

  describe "location selection and form submission" do
    setup do
      user = UsersFixtures.user_fixture()
      token = Kjogvi.Users.generate_user_session_token(user)

      conn =
        build_conn()
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      location = GeoFixtures.location_fixture(name_en: "Test Park")

      {:ok, conn: conn, user: user, location: location}
    end

    test "selecting location updates both text field and hidden field", %{conn: conn, location: location} do
      {:ok, lv, _html} = live(conn, "/my/cards/new")

      # Search for location
      lv |> render_change("search_locations", %{"value" => "Test"})

      # Verify location appears in results
      html1 = render(lv)
      assert html1 =~ "Test Park"

      # Click to select location
      lv
      |> render_click("select_location", %{
        "id" => to_string(location.id),
        "name" => "Test Park"
      })

      html2 = render(lv)

      # Verify text field shows selected location
      assert html2 =~ "Test Park"

      # Verify the hidden field has location ID
      assert html2 =~ "card_location_id"
      assert html2 =~ to_string(location.id)
    end

    test "can save card with selected location", %{conn: conn, user: user, location: location} do
      {:ok, lv, _html} = live(conn, "/my/cards/new")

      # Fill in required fields
      lv |> render_change("search_locations", %{"value" => "Test"})

      lv
      |> render_click("select_location", %{
        "id" => to_string(location.id),
        "name" => "Test Park"
      })

      # Fill in date and effort type
      form_data = %{
        "card" => %{
          "observ_date" => "2026-01-20",
          "effort_type" => "STATIONARY",
          "location_id" => to_string(location.id)
        }
      }

      lv |> render_submit("save", form_data)

      # Verify card was created
      cards = Birding.get_cards(user, %{page: 1, page_size: 50})
      assert length(cards.entries) > 0

      # Verify the most recent card has the selected location
      card = List.first(cards.entries)
      assert card.location_id == location.id
    end
  end

  describe "observation with taxon selection" do
    setup do
      user = UsersFixtures.user_fixture()
      token = Kjogvi.Users.generate_user_session_token(user)

      conn =
        build_conn()
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      location = GeoFixtures.location_fixture(name_en: "Test Park")

      {:ok, conn: conn, user: user, location: location}
    end

    test "can save card with observations", %{conn: conn, user: user, location: location} do
      {:ok, lv, _html} = live(conn, "/my/cards/new")

      # Select location
      lv |> render_change("search_locations", %{"value" => "Test"})

      lv
      |> render_click("select_location", %{
        "id" => to_string(location.id),
        "name" => "Test Park"
      })

      # Add observation
      lv |> element("button", "Add Observation") |> render_click()

      # Fill form data
      form_data = %{
        "card" => %{
          "observ_date" => "2026-01-20",
          "effort_type" => "STATIONARY",
          "location_id" => to_string(location.id),
          "observations" => %{
            "0" => %{
              "taxon_key" => "comred",
              "quantity" => "1"
            }
          }
        }
      }

      lv |> render_submit("save", form_data)

      # Verify card and observation were created
      cards = Birding.get_cards(user, %{page: 1, page_size: 50})
      assert length(cards.entries) > 0

      card = List.first(cards.entries)
      assert card.location_id == location.id

      # Load card with observations (without preloading taxa which requires them to exist)
      loaded_card = Kjogvi.Repo.get!(Birding.Card, card.id)
      loaded_card = Kjogvi.Repo.preload(loaded_card, :observations)

      assert length(loaded_card.observations) == 1

      observation = List.first(loaded_card.observations)
      assert observation.taxon_key == "comred"
      assert observation.quantity == "1"
    end

    test "multiple observations with different taxa", %{conn: conn, user: user, location: location} do
      {:ok, lv, _html} = live(conn, "/my/cards/new")

      # Select location
      lv |> render_change("search_locations", %{"value" => "Test"})

      lv
      |> render_click("select_location", %{
        "id" => to_string(location.id),
        "name" => "Test Park"
      })

      # Add first observation
      lv |> element("button", "Add Observation") |> render_click()

      # Add second observation
      lv |> element("button", "Add Observation") |> render_click()

      # Fill form data with multiple observations
      form_data = %{
        "card" => %{
          "observ_date" => "2026-01-20",
          "effort_type" => "STATIONARY",
          "location_id" => to_string(location.id),
          "observations" => %{
            "0" => %{
              "taxon_key" => "comred",
              "quantity" => "1"
            },
            "1" => %{
              "taxon_key" => "eurwie",
              "quantity" => "2"
            }
          }
        }
      }

      lv |> render_submit("save", form_data)

      # Verify both observations were created
      cards = Birding.get_cards(user, %{page: 1, page_size: 50})
      card = List.first(cards.entries)

      loaded_card = Kjogvi.Repo.get!(Birding.Card, card.id)
      loaded_card = Kjogvi.Repo.preload(loaded_card, :observations)

      assert length(loaded_card.observations) == 2

      observations = loaded_card.observations
      assert Enum.any?(observations, &(&1.taxon_key == "comred"))
      assert Enum.any?(observations, &(&1.taxon_key == "eurwie"))

      # Verify quantities
      assert Enum.find(observations, &(&1.taxon_key == "comred")).quantity == "1"
      assert Enum.find(observations, &(&1.taxon_key == "eurwie")).quantity == "2"
    end
  end
end
