defmodule KjogviWeb.Live.My.Checklists.FormTest do
  use KjogviWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Kjogvi.AccountsFixtures
  alias Kjogvi.GeoFixtures
  alias Kjogvi.Geo
  alias Kjogvi.Birding
  alias Kjogvi.Search

  defp create_user_with_book do
    book = Ornitho.Factory.insert(:book, slug: "ebird", version: "v2024")

    user = AccountsFixtures.user_fixture()

    {:ok, user} =
      Kjogvi.Accounts.update_user_preferences(user, %{"default_book_signature" => "ebird/v2024"})

    {user, book}
  end

  defp create_taxon(book, attrs) do
    Ornitho.Factory.insert(:taxon, Keyword.merge([book: book], attrs))
  end

  defp conn_for_user(user) do
    token = Kjogvi.Accounts.generate_user_session_token(user)

    build_conn()
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  defp search_and_select_taxon(lv, index, taxon_name) do
    lv |> element("#taxon_search_#{index}") |> render_keyup(%{"value" => taxon_name})
    lv |> element("#taxon_search_#{index}-result-0") |> render_click()
    render(lv)
  end

  defp search_and_select_location(lv, search_term) do
    lv |> element("#location_search") |> render_keyup(%{"value" => search_term})
    lv |> element("#location_search-result-0") |> render_click()
    render(lv)
  end

  describe "checklist form" do
    setup do
      user = AccountsFixtures.user_fixture()
      conn = conn_for_user(user)
      {:ok, conn: conn, user: user}
    end

    test "renders new checklist form", %{conn: conn} do
      {:ok, _lv, html} = live(conn, "/my/checklists/new")
      assert html =~ "New Checklist"
    end

    test "renders breadcrumbs on new checklist form", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/my/checklists/new")

      assert has_element?(lv, "#checklist-breadcrumbs")
      assert has_element?(lv, "#checklist-breadcrumbs a", "Checklists")
    end

    test "renders location field with type=search", %{conn: conn} do
      {:ok, _lv, html} = live(conn, "/my/checklists/new")
      assert html =~ "Location"
      assert html =~ "type=\"search\""
    end

    test "renders location search as hidden input for ID storage", %{conn: conn} do
      {:ok, _lv, html} = live(conn, "/my/checklists/new")
      assert html =~ "checklist[location_id]"
      assert html =~ "type=\"hidden\""
    end

    test "renders empty observation form", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/my/checklists/new")

      assert has_element?(lv, "label", "Taxon")
      assert has_element?(lv, "label", "Quantity")
    end

    test "renders observation section with add button", %{conn: conn} do
      {:ok, _lv, html} = live(conn, "/my/checklists/new")
      assert html =~ "Observations"
      assert html =~ "Add Observation"
    end

    test "can add more observation forms", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/my/checklists/new")

      lv |> element("button", "Add Observation") |> render_click()

      html = render(lv) |> Floki.parse_document!()

      assert html
             |> Floki.find("input[placeholder=\"Search and select taxon...\"]")
             |> length() == 2
    end

    test "can remove new observations immediately", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/my/checklists/new")

      assert has_element?(lv, ~s(button[aria-label="Remove observation"]))

      # New observations (without ID) get removed immediately
      lv |> element(~s(button[aria-label="Remove observation"])) |> render_click()

      html = render(lv)
      assert html =~ "No observations yet"
    end

    test "taxon input has type=search", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/my/checklists/new")

      lv |> element("button", "Add Observation") |> render_click()

      html = render(lv)
      assert html =~ "type=\"search\""
      assert html =~ "Taxon"
    end

    test "observation has hidden field for taxon_key", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/my/checklists/new")

      lv |> element("button", "Add Observation") |> render_click()

      html = render(lv)
      assert html =~ "type=\"hidden\""
      assert html =~ "taxon_key"
    end

    test "can add multiple observations", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/my/checklists/new")

      lv |> element("button", "Add Observation") |> render_click()
      lv |> element("button", "Add Observation") |> render_click()

      assert has_element?(lv, ~s(button[aria-label="Remove observation"]))
    end

    test "renders Resolved checkbox checked by default on new checklist", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/my/checklists/new")

      assert has_element?(lv, "label", "Resolved")
      assert has_element?(lv, "input#checklist_resolved[type=checkbox][checked]")
    end

    test "location search results display with dropdown styling", %{conn: conn} do
      _location = GeoFixtures.location_fixture(name_en: "Central Park")
      {:ok, lv, _html} = live(conn, "/my/checklists/new")

      html = lv |> element("#location_search") |> render_keyup(%{"value" => "Central"})
      assert html =~ "<strong>Central</strong> Park"
    end

    test "can select location from search results", %{conn: conn} do
      _location = GeoFixtures.location_fixture(name_en: "Central Park")
      {:ok, lv, _html} = live(conn, "/my/checklists/new")

      lv |> element("#location_search") |> render_keyup(%{"value" => "Central"})
      lv |> element("#location_search-result-0") |> render_click()

      html = render(lv)
      assert html =~ "Central Park"
    end

    test "location autocomplete offers own and common locations but not another user's",
         %{conn: conn, user: user} do
      _own =
        GeoFixtures.location_fixture(
          name_en: "Owned Park",
          location_type: "city",
          user_id: user.id
        )

      _common = GeoFixtures.location_fixture(name_en: "Common Park", location_type: "city")

      _other =
        GeoFixtures.location_fixture(
          name_en: "Other Park",
          location_type: "city",
          user_id: AccountsFixtures.user_fixture().id
        )

      {:ok, lv, _html} = live(conn, "/my/checklists/new")
      html = lv |> element("#location_search") |> render_keyup(%{"value" => "Park"})

      assert html =~ "Owned"
      assert html =~ "Common"
      refute html =~ "Other Park"
    end

    test "location autocomplete does not suggest special locations", %{conn: conn} do
      _regular = GeoFixtures.location_fixture(name_en: "Regular Park", location_type: "city")
      _special = GeoFixtures.location_fixture(name_en: "Special Park", location_type: "special")

      {:ok, lv, _html} = live(conn, "/my/checklists/new")
      html = lv |> element("#location_search") |> render_keyup(%{"value" => "Park"})

      assert html =~ "Regular"
      refute html =~ "Special"
    end
  end

  describe "location search" do
    test "search_locations filters by query" do
      location1 = GeoFixtures.location_fixture(name_en: "Central Park")
      location2 = GeoFixtures.location_fixture(name_en: "Hyde Park")

      results = Search.Location.search_locations(Geo.Location, "Central")
      assert Enum.any?(results, &(&1.id == location1.id))
      refute Enum.any?(results, &(&1.id == location2.id))
    end

    test "search_locations includes hidden locations" do
      _public = GeoFixtures.location_fixture(name_en: "Public Park", is_private: false)
      _private = GeoFixtures.location_fixture(name_en: "Private Park", is_private: true)

      results = Search.Location.search_locations(Geo.Location, "Park")

      assert Enum.any?(
               results,
               &String.contains?(Geo.Location.long_name(:private, &1), "Public")
             )

      assert Enum.any?(
               results,
               &String.contains?(Geo.Location.long_name(:private, &1), "Private")
             )
    end

    test "search_locations prioritizes exact match" do
      _exact = GeoFixtures.location_fixture(name_en: "Park")
      _prefix = GeoFixtures.location_fixture(name_en: "Park Lane")

      results = Search.Location.search_locations(Geo.Location, "Park")
      assert results != []
      assert Geo.Location.long_name(:private, Enum.at(results, 0)) =~ "Park"
    end
  end

  describe "effort types enum" do
    test "can retrieve effort types as list" do
      types = Kjogvi.Birding.Checklist.effort_types()
      assert Enum.member?(types, "STATIONARY")
      assert Enum.member?(types, "TRAVEL")
    end

    test "effort types includes all expected values" do
      types = Kjogvi.Birding.Checklist.effort_types()
      assert Enum.member?(types, "STATIONARY")
      assert Enum.member?(types, "TRAVEL")
      assert Enum.member?(types, "AREA")
      assert Enum.member?(types, "INCIDENTAL")
      assert Enum.member?(types, "HISTORICAL")
    end

    test "all effort types are strings" do
      types = Kjogvi.Birding.Checklist.effort_types()
      assert Enum.all?(types, &is_binary/1)
    end
  end

  describe "location selection and form submission" do
    setup do
      user = AccountsFixtures.user_fixture()
      conn = conn_for_user(user)
      location = GeoFixtures.location_fixture(name_en: "Test Park")
      {:ok, conn: conn, user: user, location: location}
    end

    test "selecting location updates both text field and hidden field", %{
      conn: conn,
      location: location
    } do
      {:ok, lv, _html} = live(conn, "/my/checklists/new")

      # Search for location
      html1 = lv |> element("#location_search") |> render_keyup(%{"value" => "Test"})

      # Verify location appears in results
      assert html1 =~ "<strong>Test</strong> Park"

      # Click to select location
      lv |> element("#location_search-result-0") |> render_click()
      html2 = render(lv)

      # Verify text field shows selected location
      assert html2 =~ "Test Park"

      # Verify the hidden field has location ID
      assert html2 =~ "checklist[location_id]"
      assert html2 =~ to_string(location.id)
    end

    test "can save checklist with selected location", %{
      conn: conn,
      user: user,
      location: location
    } do
      {:ok, lv, _html} = live(conn, "/my/checklists/new")

      # Select location via autocomplete
      search_and_select_location(lv, "Test")

      # Fill in date and effort type
      form_data = %{
        "checklist" => %{
          "observ_date" => "2026-01-20",
          "effort_type" => "STATIONARY",
          "start_time" => "08:00",
          "duration_minutes" => "30",
          "location_id" => to_string(location.id)
        }
      }

      lv |> render_submit("save", form_data)

      # Verify checklist was created
      checklists = Birding.get_checklists(user, %{page: 1, page_size: 50})
      assert checklists.entries != []

      # Verify the most recent checklist has the selected location
      checklist = List.first(checklists.entries)
      assert checklist.location_id == location.id
    end

    test "saves checklist as resolved by default", %{conn: conn, user: user, location: location} do
      {:ok, lv, _html} = live(conn, "/my/checklists/new")

      search_and_select_location(lv, "Test")

      form_data = %{
        "checklist" => %{
          "observ_date" => "2026-01-20",
          "effort_type" => "INCIDENTAL",
          "location_id" => to_string(location.id),
          "resolved" => "true"
        }
      }

      lv |> render_submit("save", form_data)

      checklist =
        user
        |> Birding.get_checklists(%{page: 1, page_size: 50})
        |> Map.get(:entries)
        |> List.first()

      assert checklist.resolved == true
    end

    test "saves checklist as unresolved when checkbox unchecked", %{
      conn: conn,
      user: user,
      location: location
    } do
      {:ok, lv, _html} = live(conn, "/my/checklists/new")

      search_and_select_location(lv, "Test")

      form_data = %{
        "checklist" => %{
          "observ_date" => "2026-01-20",
          "effort_type" => "INCIDENTAL",
          "location_id" => to_string(location.id),
          "resolved" => "false"
        }
      }

      lv |> render_submit("save", form_data)

      checklist =
        user
        |> Birding.get_checklists(%{page: 1, page_size: 50})
        |> Map.get(:entries)
        |> List.first()

      assert checklist.resolved == false
    end

    test "ebird_complete defaults to nil with neither switch option selected", %{
      conn: conn,
      user: user,
      location: location
    } do
      {:ok, lv, _html} = live(conn, "/my/checklists/new")

      refute has_element?(lv, ~s(input[name="checklist[ebird_complete]"][value="true"][checked]))
      refute has_element?(lv, ~s(input[name="checklist[ebird_complete]"][value="false"][checked]))

      search_and_select_location(lv, "Test")

      form_data = %{
        "checklist" => %{
          "observ_date" => "2026-01-20",
          "effort_type" => "INCIDENTAL",
          "location_id" => to_string(location.id)
        }
      }

      lv |> render_submit("save", form_data)

      checklist =
        user
        |> Birding.get_checklists(%{page: 1, page_size: 50})
        |> Map.get(:entries)
        |> List.first()

      assert checklist.ebird_complete == nil
    end

    test "saves ebird_complete as true when YES selected", %{
      conn: conn,
      user: user,
      location: location
    } do
      {:ok, lv, _html} = live(conn, "/my/checklists/new")

      search_and_select_location(lv, "Test")

      form_data = %{
        "checklist" => %{
          "observ_date" => "2026-01-20",
          "effort_type" => "INCIDENTAL",
          "location_id" => to_string(location.id),
          "ebird_complete" => "true"
        }
      }

      lv |> render_submit("save", form_data)

      checklist =
        user
        |> Birding.get_checklists(%{page: 1, page_size: 50})
        |> Map.get(:entries)
        |> List.first()

      assert checklist.ebird_complete == true
    end

    test "saves ebird_complete as false when NO selected", %{
      conn: conn,
      user: user,
      location: location
    } do
      {:ok, lv, _html} = live(conn, "/my/checklists/new")

      search_and_select_location(lv, "Test")

      form_data = %{
        "checklist" => %{
          "observ_date" => "2026-01-20",
          "effort_type" => "INCIDENTAL",
          "location_id" => to_string(location.id),
          "ebird_complete" => "false"
        }
      }

      lv |> render_submit("save", form_data)

      checklist =
        user
        |> Birding.get_checklists(%{page: 1, page_size: 50})
        |> Map.get(:entries)
        |> List.first()

      assert checklist.ebird_complete == false
    end
  end

  describe "observation with taxon selection" do
    setup do
      {user, book} = create_user_with_book()
      conn = conn_for_user(user)
      location = GeoFixtures.location_fixture(name_en: "Test Park")

      houspa =
        create_taxon(book,
          code: "houspa",
          name_en: "House Sparrow",
          name_sci: "Passer domesticus"
        )

      comred =
        create_taxon(book,
          code: "comred",
          name_en: "Common Redstart",
          name_sci: "Phoenicurus phoenicurus"
        )

      eurwie =
        create_taxon(book,
          code: "eurwie",
          name_en: "Eurasian Wigeon",
          name_sci: "Mareca penelope"
        )

      {:ok,
       conn: conn,
       user: user,
       book: book,
       location: location,
       houspa: houspa,
       comred: comred,
       eurwie: eurwie}
    end

    test "can save checklist with observations", %{conn: conn, user: user, location: location} do
      {:ok, lv, _html} = live(conn, "/my/checklists/new")

      # Select location
      search_and_select_location(lv, "Test")

      # Add observation and select taxon via search
      lv |> element("button", "Add Observation") |> render_click()
      search_and_select_taxon(lv, 0, "Common Redstart")

      # Fill form data
      form_data = %{
        "checklist" => %{
          "observ_date" => "2026-01-20",
          "effort_type" => "STATIONARY",
          "start_time" => "08:00",
          "duration_minutes" => "30",
          "location_id" => to_string(location.id),
          "observations" => %{
            "0" => %{
              "taxon_key" => "/ebird/v2024/comred",
              "quantity" => "1"
            }
          }
        }
      }

      lv |> render_submit("save", form_data)

      # Verify checklist and observation were created
      checklists = Birding.get_checklists(user, %{page: 1, page_size: 50})
      assert checklists.entries != []

      checklist = List.first(checklists.entries)
      assert checklist.location_id == location.id

      loaded_checklist = Kjogvi.Repo.get!(Birding.Checklist, checklist.id)
      loaded_checklist = Kjogvi.Repo.preload(loaded_checklist, :observations)

      assert length(loaded_checklist.observations) == 1

      observation = List.first(loaded_checklist.observations)
      assert observation.taxon_key == "/ebird/v2024/comred"
      assert observation.quantity == "1"
    end

    test "multiple observations with different taxa", %{
      conn: conn,
      user: user,
      location: location
    } do
      {:ok, lv, _html} = live(conn, "/my/checklists/new")

      # Select location
      search_and_select_location(lv, "Test")

      # Add observations and select taxa via search
      lv |> element("button", "Add Observation") |> render_click()
      lv |> element("button", "Add Observation") |> render_click()

      search_and_select_taxon(lv, 0, "Common Redstart")
      search_and_select_taxon(lv, 1, "Eurasian Wigeon")

      # Fill form data with multiple observations
      form_data = %{
        "checklist" => %{
          "observ_date" => "2026-01-20",
          "effort_type" => "STATIONARY",
          "start_time" => "08:00",
          "duration_minutes" => "30",
          "location_id" => to_string(location.id),
          "observations" => %{
            "0" => %{
              "taxon_key" => "/ebird/v2024/comred",
              "quantity" => "1"
            },
            "1" => %{
              "taxon_key" => "/ebird/v2024/eurwie",
              "quantity" => "2"
            }
          }
        }
      }

      lv |> render_submit("save", form_data)

      # Verify both observations were created
      checklists = Birding.get_checklists(user, %{page: 1, page_size: 50})
      checklist = List.first(checklists.entries)

      loaded_checklist = Kjogvi.Repo.get!(Birding.Checklist, checklist.id)
      loaded_checklist = Kjogvi.Repo.preload(loaded_checklist, :observations)

      assert length(loaded_checklist.observations) == 2

      observations = loaded_checklist.observations
      assert Enum.any?(observations, &(&1.taxon_key == "/ebird/v2024/comred"))
      assert Enum.any?(observations, &(&1.taxon_key == "/ebird/v2024/eurwie"))

      assert Enum.find(observations, &(&1.taxon_key == "/ebird/v2024/comred")).quantity == "1"
      assert Enum.find(observations, &(&1.taxon_key == "/ebird/v2024/eurwie")).quantity == "2"
    end

    test "select_taxon event updates form and shows display name", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/my/checklists/new")

      # Add observation
      lv |> element("button", "Add Observation") |> render_click()

      # Search and select taxon
      search_and_select_taxon(lv, 0, "Common Redstart")

      html = render(lv)

      # Verify the taxon display name appears in the search input
      assert html =~ "Common Redstart"
      assert html =~ "Phoenicurus phoenicurus"

      # Verify the hidden field has the taxon code
      assert html =~ "/ebird/v2024/comred"
    end

    test "multiple observations can have different taxa selected via UI", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/my/checklists/new")

      # Add two observations
      lv |> element("button", "Add Observation") |> render_click()
      lv |> element("button", "Add Observation") |> render_click()

      # Search and select taxa
      search_and_select_taxon(lv, 0, "Common Redstart")
      search_and_select_taxon(lv, 1, "Eurasian Wigeon")

      html = render(lv)

      # Verify both taxa display names appear
      assert html =~ "Common Redstart"
      assert html =~ "Eurasian Wigeon"

      # Verify both taxon codes are in hidden fields
      assert html =~ "/ebird/v2024/comred"
      assert html =~ "/ebird/v2024/eurwie"
    end

    test "removing new observation preserves remaining taxa", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/my/checklists/new")

      # Add three observations
      lv |> element("button", "Add Observation") |> render_click()
      lv |> element("button", "Add Observation") |> render_click()
      lv |> element("button", "Add Observation") |> render_click()

      # Select taxa for all observations
      search_and_select_taxon(lv, 0, "House Sparrow")
      search_and_select_taxon(lv, 1, "Common Redstart")
      search_and_select_taxon(lv, 2, "Eurasian Wigeon")

      html = render(lv)
      assert html =~ "House Sparrow"
      assert html =~ "Common Redstart"
      assert html =~ "Eurasian Wigeon"

      # Remove the middle observation (index 1) - new observations are removed immediately
      lv |> render_click("remove_observation", %{"index" => "1"})

      html = render(lv)

      # First and third (now second) should still show
      assert html =~ "House Sparrow"
      assert html =~ "Eurasian Wigeon"

      # Second taxon should be gone
      refute html =~ "Common Redstart"
    end
  end

  describe "editing existing checklist" do
    setup do
      user = AccountsFixtures.user_fixture()
      conn = conn_for_user(user)

      location1 = GeoFixtures.location_fixture(name_en: "Original Park")
      location2 = GeoFixtures.location_fixture(name_en: "New Park")

      checklist =
        Kjogvi.BirdingFixtures.checklist_fixture(%{
          user: user,
          location_id: location1.id,
          observ_date: ~D[2026-01-15],
          effort_type: "STATIONARY"
        })

      {:ok,
       conn: conn, user: user, checklist: checklist, location1: location1, location2: location2}
    end

    test "renders breadcrumbs on edit checklist form with link to checklist", %{
      conn: conn,
      checklist: checklist
    } do
      {:ok, lv, _html} = live(conn, "/my/checklists/#{checklist.id}/edit")

      assert has_element?(lv, "#checklist-breadcrumbs")
      assert has_element?(lv, "#checklist-breadcrumbs a", "Checklists")
      assert has_element?(lv, "#checklist-breadcrumbs a", "Checklist ##{checklist.id}")
    end

    test "can edit checklist and change location", %{
      conn: conn,
      checklist: checklist,
      location1: location1,
      location2: location2
    } do
      {:ok, lv, html} = live(conn, "/my/checklists/#{checklist.id}/edit")

      # Verify we're on the edit page with original location
      assert html =~ "Edit Checklist"
      assert html =~ "Original Park"

      # Search for and select new location
      search_and_select_location(lv, "New")

      # Submit the form
      form_data = %{
        "checklist" => %{
          "observ_date" => "2026-01-15",
          "effort_type" => "STATIONARY",
          "location_id" => to_string(location2.id)
        }
      }

      lv |> render_submit("save", form_data)

      # Verify checklist was updated
      updated_checklist = Kjogvi.Repo.get!(Birding.Checklist, checklist.id)
      assert updated_checklist.location_id == location2.id
      refute updated_checklist.location_id == location1.id
    end

    test "can edit checklist and add new observations", %{
      conn: conn,
      checklist: checklist,
      location1: location1
    } do
      {:ok, lv, _html} = live(conn, "/my/checklists/#{checklist.id}/edit")

      # Add two observations
      lv |> element("button", "Add Observation") |> render_click()
      lv |> element("button", "Add Observation") |> render_click()

      # Submit with new observations
      form_data = %{
        "checklist" => %{
          "observ_date" => "2026-01-15",
          "effort_type" => "STATIONARY",
          "location_id" => to_string(location1.id),
          "observations" => %{
            "0" => %{
              "taxon_key" => "/ebird/v2024/houspa",
              "quantity" => "2"
            },
            "1" => %{
              "taxon_key" => "/ebird/v2024/comred",
              "quantity" => "3"
            }
          }
        }
      }

      lv |> render_submit("save", form_data)

      # Verify observations were saved
      updated_checklist = Kjogvi.Repo.get!(Birding.Checklist, checklist.id)
      updated_checklist = Kjogvi.Repo.preload(updated_checklist, :observations)

      assert length(updated_checklist.observations) == 2
      assert Enum.any?(updated_checklist.observations, &(&1.taxon_key == "/ebird/v2024/houspa"))
      assert Enum.any?(updated_checklist.observations, &(&1.taxon_key == "/ebird/v2024/comred"))
    end

    test "toggling a checkbox does not crash when start time has seconds", %{
      conn: conn,
      checklist: checklist,
      location1: location1
    } do
      {:ok, lv, _html} = live(conn, "/my/checklists/#{checklist.id}/edit")

      # An existing checklist's start_time renders with seconds in some browsers
      # ("08:00:00"). A phx-change (e.g. a checkbox toggle) must not crash while
      # parsing it back into a Time.
      html =
        lv
        |> render_change("sync_checklist", %{
          "checklist" => %{
            "observ_date" => "2026-01-15",
            "effort_type" => "STATIONARY",
            "location_id" => to_string(location1.id),
            "start_time" => "08:00:00",
            "resolved" => "false"
          }
        })

      assert html =~ "Edit Checklist"
      assert has_element?(lv, "#checklist-form")
    end

    test "edit form shows start time as HH:MM in the time input", %{
      conn: conn,
      checklist: checklist
    } do
      {:ok, lv, _html} = live(conn, "/my/checklists/#{checklist.id}/edit")

      assert has_element?(lv, ~s(input#checklist_start_time[type="time"][value="08:00"]))
    end

    test "can edit existing observation", %{
      conn: conn,
      checklist: checklist,
      location1: location1
    } do
      # Add an observation to the existing checklist
      {:ok, obs} =
        Kjogvi.Repo.insert(%Kjogvi.Birding.Observation{
          checklist_id: checklist.id,
          taxon_key: "/ebird/v2024/houspa",
          quantity: "1"
        })

      {:ok, lv, _html} = live(conn, "/my/checklists/#{checklist.id}/edit")

      # Submit with updated observation (including the ID)
      form_data = %{
        "checklist" => %{
          "observ_date" => "2026-01-15",
          "effort_type" => "STATIONARY",
          "location_id" => to_string(location1.id),
          "observations" => %{
            "0" => %{
              "id" => to_string(obs.id),
              "taxon_key" => "/ebird/v2024/houspa",
              "quantity" => "5"
            }
          }
        }
      }

      lv |> render_submit("save", form_data)

      # Verify observation was updated
      updated_obs = Kjogvi.Repo.get!(Kjogvi.Birding.Observation, obs.id)
      assert updated_obs.quantity == "5"
    end

    test "can mark existing observation for deletion and restore it", %{
      conn: conn,
      checklist: checklist
    } do
      # Add an observation to the existing checklist
      {:ok, _obs} =
        Kjogvi.Repo.insert(%Kjogvi.Birding.Observation{
          checklist_id: checklist.id,
          taxon_key: "/ebird/v2024/houspa",
          quantity: "1"
        })

      {:ok, lv, _html} = live(conn, "/my/checklists/#{checklist.id}/edit")

      # Existing observation should have Remove button
      assert has_element?(lv, ~s(button[aria-label="Remove observation"]))

      # Mark for deletion
      lv |> element(~s(button[aria-label="Remove observation"])) |> render_click()

      html = render(lv)
      # Should show as grayed out with Restore button
      assert html =~ "Restore"
      assert html =~ "line-through"

      # Restore the observation
      lv |> element("button", "Restore") |> render_click()

      # Should be back to normal with Remove button
      assert has_element?(lv, ~s(button[aria-label="Remove observation"]))
      refute render(lv) =~ "line-through"
    end
  end

  describe "double submit protection" do
    setup do
      user = AccountsFixtures.user_fixture()
      conn = conn_for_user(user)
      location = GeoFixtures.location_fixture(name_en: "Test Park")
      {:ok, conn: conn, user: user, location: location}
    end

    test "submit button has phx-disable-with attribute", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/my/checklists/new")

      assert has_element?(lv, ~s(button[type="submit"][phx-disable-with]))
    end

    test "successful submit navigates away, preventing double submit", %{
      conn: conn,
      user: user,
      location: location
    } do
      {:ok, lv, _html} = live(conn, "/my/checklists/new")

      search_and_select_location(lv, "Test")

      form_data = %{
        "checklist" => %{
          "observ_date" => "2026-01-20",
          "effort_type" => "STATIONARY",
          "start_time" => "08:00",
          "duration_minutes" => "30",
          "location_id" => to_string(location.id)
        }
      }

      # First submit navigates away from the form
      lv |> render_submit("save", form_data)
      {path, _flash} = assert_redirect(lv)
      assert path =~ ~r"/my/checklists/\d+"

      # Only one checklist was created
      checklists = Birding.get_checklists(user, %{page: 1, page_size: 50})
      assert length(checklists.entries) == 1
    end
  end

  describe "form validation errors" do
    setup do
      {user, book} = create_user_with_book()
      conn = conn_for_user(user)

      _houspa =
        create_taxon(book,
          code: "houspa",
          name_en: "House Sparrow",
          name_sci: "Passer domesticus"
        )

      _comred =
        create_taxon(book,
          code: "comred",
          name_en: "Common Redstart",
          name_sci: "Phoenicurus phoenicurus"
        )

      {:ok, conn: conn, user: user}
    end

    test "shows error message when location is missing", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/my/checklists/new")

      # Submit form without location
      form_data = %{
        "checklist" => %{
          "observ_date" => "2026-01-20",
          "effort_type" => "STATIONARY"
        }
      }

      html = lv |> render_submit("save", form_data)

      # Should show validation error for missing location
      assert html =~ "can&#39;t be blank" or html =~ "can't be blank"
    end

    test "can add observations after validation failure", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/my/checklists/new")

      # Add first observation and select taxon
      lv |> element("button", "Add Observation") |> render_click()
      search_and_select_taxon(lv, 0, "House Sparrow")

      # Add second observation and select taxon
      lv |> element("button", "Add Observation") |> render_click()
      search_and_select_taxon(lv, 1, "Common Redstart")

      # Submit form without location (this will fail validation)
      form_data = %{
        "checklist" => %{
          "observ_date" => "2026-01-20",
          "effort_type" => "STATIONARY",
          "observations" => %{
            "0" => %{
              "taxon_key" => "/ebird/v2024/houspa",
              "quantity" => "1"
            },
            "1" => %{
              "taxon_key" => "/ebird/v2024/comred",
              "quantity" => "2"
            }
          }
        }
      }

      _html = lv |> render_submit("save", form_data)

      # Now try to add another observation - this should work without error
      lv |> element("button", "Add Observation") |> render_click()

      html = render(lv)

      # Should have 3 observation forms now
      # The original 2 should still be there plus the new empty one
      assert html =~ "House Sparrow"
      assert html =~ "Common Redstart"
    end

    test "preserves observations after validation failure", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/my/checklists/new")

      # Add two observations
      lv |> element("button", "Add Observation") |> render_click()
      lv |> element("button", "Add Observation") |> render_click()

      # Select taxa via search
      search_and_select_taxon(lv, 0, "House Sparrow")
      search_and_select_taxon(lv, 1, "Common Redstart")

      # Submit form without location (this will fail validation)
      form_data = %{
        "checklist" => %{
          "observ_date" => "2026-01-20",
          "effort_type" => "STATIONARY",
          "observations" => %{
            "0" => %{
              "taxon_key" => "/ebird/v2024/houspa",
              "quantity" => "1"
            },
            "1" => %{
              "taxon_key" => "/ebird/v2024/comred",
              "quantity" => "2"
            }
          }
        }
      }

      html = lv |> render_submit("save", form_data)

      # Both observations should still be visible after validation failure
      assert html =~ "House Sparrow"
      assert html =~ "Common Redstart"
    end

    test "empty observation rows are ignored on save", %{conn: conn, user: user} do
      location = GeoFixtures.location_fixture(name_en: "Test Park")
      {:ok, lv, _html} = live(conn, "/my/checklists/new")

      # Select location
      search_and_select_location(lv, "Test")

      # Add an observation with taxon and an empty one
      lv |> element("button", "Add Observation") |> render_click()
      lv |> element("button", "Add Observation") |> render_click()
      search_and_select_taxon(lv, 0, "House Sparrow")

      # Submit - second observation is empty, should be ignored
      form_data = %{
        "checklist" => %{
          "observ_date" => "2026-01-20",
          "effort_type" => "STATIONARY",
          "start_time" => "08:00",
          "duration_minutes" => "30",
          "location_id" => to_string(location.id),
          "observations" => %{
            "0" => %{"taxon_key" => "/ebird/v2024/houspa", "quantity" => "3"},
            "1" => %{"taxon_key" => "", "quantity" => "", "notes" => "", "private_notes" => ""}
          }
        }
      }

      lv |> render_submit("save", form_data)

      # Checklist saved with only the filled observation
      checklists = Birding.get_checklists(user, %{page: 1, page_size: 50})
      checklist = List.first(checklists.entries)

      loaded_checklist =
        Kjogvi.Repo.preload(Kjogvi.Repo.get!(Birding.Checklist, checklist.id), :observations)

      assert length(loaded_checklist.observations) == 1
      assert List.first(loaded_checklist.observations).taxon_key == "/ebird/v2024/houspa"
    end

    test "partially filled observation shows taxon_key error", %{conn: conn} do
      location = GeoFixtures.location_fixture(name_en: "Test Park")
      {:ok, lv, _html} = live(conn, "/my/checklists/new")

      # Select location
      search_and_select_location(lv, "Test")

      # Add an observation with quantity but no taxon
      lv |> element("button", "Add Observation") |> render_click()

      form_data = %{
        "checklist" => %{
          "observ_date" => "2026-01-20",
          "effort_type" => "STATIONARY",
          "start_time" => "08:00",
          "duration_minutes" => "30",
          "location_id" => to_string(location.id),
          "observations" => %{
            "0" => %{"taxon_key" => "", "quantity" => "5"}
          }
        }
      }

      html = lv |> render_submit("save", form_data)

      # Should show validation error for missing taxon
      assert html =~ "can&#39;t be blank" or html =~ "can't be blank"
    end

    test "rejects a special location on save", %{conn: conn, user: user} do
      special = GeoFixtures.location_fixture(name_en: "Special Park", location_type: "special")
      {:ok, lv, _html} = live(conn, "/my/checklists/new")

      form_data = %{
        "checklist" => %{
          "observ_date" => "2026-01-20",
          "effort_type" => "INCIDENTAL",
          "location_id" => to_string(special.id)
        }
      }

      html = lv |> render_submit("save", form_data)

      assert html =~ "is not available"
      assert Birding.get_checklists(user, %{page: 1, page_size: 50}).entries == []
    end

    test "checklist with no observations saves successfully", %{conn: conn, user: user} do
      location = GeoFixtures.location_fixture(name_en: "Test Park")
      {:ok, lv, _html} = live(conn, "/my/checklists/new")

      search_and_select_location(lv, "Test")

      form_data = %{
        "checklist" => %{
          "observ_date" => "2026-01-20",
          "effort_type" => "STATIONARY",
          "start_time" => "08:00",
          "duration_minutes" => "30",
          "location_id" => to_string(location.id)
        }
      }

      lv |> render_submit("save", form_data)

      checklists = Birding.get_checklists(user, %{page: 1, page_size: 50})
      assert checklists.entries != []
    end
  end
end
