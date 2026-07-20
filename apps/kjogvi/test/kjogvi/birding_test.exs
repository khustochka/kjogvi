defmodule Kjogvi.BirdingTest do
  use Kjogvi.DataCase, async: true

  import Kjogvi.AccountsFixtures

  alias Kjogvi.Birding
  alias Kjogvi.Birding.Checklist

  describe "find_new_checklists/2" do
    test "returns unreported checklists" do
      user = user_fixture()
      insert(:checklist, user: user, ebird_id: "S100803884")
      insert(:checklist, user: user, ebird_id: "S100803921")

      new_checklists = [%{ebird_id: "S100878702"}, %{ebird_id: "S100803921"}]

      assert Birding.find_new_checklists(user, new_checklists) ==
               [%{ebird_id: "S100878702"}]
    end
  end

  describe "create_checklist/2" do
    test "creates a checklist with valid attributes" do
      user = user_fixture()
      location = insert(:location)

      attrs = %{
        "observ_date" => "2024-05-10",
        "location_id" => location.id,
        "effort_type" => "STATIONARY",
        "start_time" => "08:00:00",
        "duration_minutes" => 30
      }

      assert {:ok, checklist} = Birding.create_checklist(user, attrs)
      assert checklist.user_id == user.id
      assert checklist.observ_date == ~D[2024-05-10]
      assert checklist.effort_type == "STATIONARY"
      assert checklist.location_id == location.id
    end

    test "returns error changeset with invalid attributes" do
      user = user_fixture()

      assert {:error, changeset} = Birding.create_checklist(user, %{})
      refute changeset.valid?
    end

    test "requires observ_date, location_id, and user_id" do
      changeset = Checklist.changeset(%Checklist{}, %{})

      refute changeset.valid?

      assert %{
               observ_date: ["can't be blank"],
               location_id: ["can't be blank"],
               user_id: ["can't be blank"]
             } = errors_on(changeset)

      refute Map.has_key?(errors_on(changeset), :effort_type)
    end

    test "creates a checklist with observations" do
      user = user_fixture()
      location = insert(:location)

      attrs = %{
        "observ_date" => "2024-05-10",
        "location_id" => location.id,
        "effort_type" => "STATIONARY",
        "start_time" => "08:00:00",
        "duration_minutes" => 30,
        "observations" => %{
          "0" => %{"taxon_key" => "ebird/eBird_2023/bkcchi1", "quantity" => "3"}
        }
      }

      assert {:ok, checklist} = Birding.create_checklist(user, attrs)
      checklist = Repo.preload(checklist, :observations)
      assert length(checklist.observations) == 1
      assert hd(checklist.observations).taxon_key == "ebird/eBird_2023/bkcchi1"
      assert hd(checklist.observations).quantity == "3"
    end

    test "promotes observed taxa that lack a species page" do
      user = user_fixture()
      location = insert(:location)
      taxon = Ornitho.Factory.insert(:taxon, category: "species")
      key = Ornitho.Schema.Taxon.key(taxon)

      refute Kjogvi.Pages.Species.from_taxon_key(key)

      attrs = %{
        "observ_date" => "2024-05-10",
        "location_id" => location.id,
        "effort_type" => "INCIDENTAL",
        "observations" => %{"0" => %{"taxon_key" => key}}
      }

      assert {:ok, _checklist} = Birding.create_checklist(user, attrs)
      assert Kjogvi.Pages.Species.from_taxon_key(key)
    end
  end

  describe "checklist location ownership" do
    test "create_checklist accepts a common location" do
      user = user_fixture()
      location = insert(:location, location_type: "city")

      assert {:ok, _checklist} = Birding.create_checklist(user, valid_checklist_attrs(location))
    end

    test "create_checklist accepts the user's own location" do
      user = user_fixture()
      location = insert(:location, location_type: "city", user_id: user.id)

      assert {:ok, _checklist} = Birding.create_checklist(user, valid_checklist_attrs(location))
    end

    test "create_checklist rejects another user's location" do
      user = user_fixture()
      location = insert(:location, location_type: "city", user_id: user_fixture().id)

      assert {:error, changeset} = Birding.create_checklist(user, valid_checklist_attrs(location))
      assert "is not available" in errors_on(changeset).location_id
    end

    test "update_checklist rejects switching to another user's location" do
      user = user_fixture()
      own = insert(:location, location_type: "city", user_id: user.id)
      other = insert(:location, location_type: "city", user_id: user_fixture().id)

      {:ok, checklist} = Birding.create_checklist(user, valid_checklist_attrs(own))

      assert {:error, changeset} =
               Birding.update_checklist(checklist, %{"location_id" => other.id})

      assert "is not available" in errors_on(changeset).location_id
    end
  end

  defp valid_checklist_attrs(location) do
    %{
      "observ_date" => "2024-05-10",
      "location_id" => location.id,
      "effort_type" => "INCIDENTAL"
    }
  end

  describe "update_checklist/2" do
    test "updates a checklist with valid attributes" do
      user = user_fixture()
      checklist = insert(:checklist, user: user)

      assert {:ok, updated} =
               Birding.update_checklist(checklist, %{
                 "effort_type" => "TRAVEL",
                 "start_time" => "09:00:00",
                 "duration_minutes" => 60,
                 "distance_kms" => 5.0
               })

      assert updated.effort_type == "TRAVEL"
    end

    test "returns error changeset with invalid attributes" do
      user = user_fixture()
      checklist = insert(:checklist, user: user)

      assert {:error, changeset} = Birding.update_checklist(checklist, %{"observ_date" => nil})
      refute changeset.valid?
    end

    test "promotes taxa added to the checklist" do
      user = user_fixture()
      checklist = insert(:checklist, user: user) |> Repo.preload(:observations)
      taxon = Ornitho.Factory.insert(:taxon, category: "species")
      key = Ornitho.Schema.Taxon.key(taxon)

      refute Kjogvi.Pages.Species.from_taxon_key(key)

      assert {:ok, _updated} =
               Birding.update_checklist(checklist, %{
                 "observations" => %{"0" => %{"taxon_key" => key}}
               })

      assert Kjogvi.Pages.Species.from_taxon_key(key)
    end
  end

  describe "change_checklist/1" do
    test "returns a changeset for a checklist" do
      user = user_fixture()
      checklist = insert(:checklist, user: user)

      changeset = Birding.change_checklist(checklist)
      assert %Ecto.Changeset{} = changeset
    end

    test "applies given attrs to the changeset" do
      user = user_fixture()
      checklist = insert(:checklist, user: user)

      changeset = Birding.change_checklist(checklist, %{"notes" => "Updated note"})
      assert Ecto.Changeset.get_change(changeset, :notes) == "Updated note"
    end
  end

  describe "new_checklist/1" do
    test "returns a new checklist struct for the user" do
      user = user_fixture()

      checklist = Birding.new_checklist(user)
      assert %Checklist{} = checklist
      assert checklist.user_id == user.id
      assert checklist.motorless == false
      assert checklist.legacy_autogenerated == false
      assert checklist.resolved == true
      assert checklist.observations == []
    end

    test "prefills observ_date with the day after the latest checklist" do
      user = user_fixture()
      insert(:checklist, user: user, observ_date: ~D[2024-01-15])
      insert(:checklist, user: user, observ_date: ~D[2024-01-10])

      checklist = Birding.new_checklist(user)
      assert checklist.observ_date == ~D[2024-01-16]
    end

    test "prefills today when the latest checklist is today" do
      user = user_fixture()
      insert(:checklist, user: user, observ_date: Date.utc_today())

      checklist = Birding.new_checklist(user)
      assert checklist.observ_date == Date.utc_today()
    end

    test "prefills today when the latest checklist is yesterday" do
      user = user_fixture()
      insert(:checklist, user: user, observ_date: Date.add(Date.utc_today(), -1))

      checklist = Birding.new_checklist(user)
      assert checklist.observ_date == Date.utc_today()
    end
  end

  describe "next_empty_date/1" do
    test "returns today when the user has no checklists" do
      user = user_fixture()
      assert Birding.next_empty_date(user) == Date.utc_today()
    end

    test "returns latest checklist date + 1 when in the past" do
      user = user_fixture()
      insert(:checklist, user: user, observ_date: ~D[2024-03-10])

      assert Birding.next_empty_date(user) == ~D[2024-03-11]
    end

    test "returns today when the latest checklist is today" do
      user = user_fixture()
      insert(:checklist, user: user, observ_date: Date.utc_today())

      assert Birding.next_empty_date(user) == Date.utc_today()
    end

    test "ignores checklists from other users" do
      user = user_fixture()
      other_user = user_fixture()
      insert(:checklist, user: other_user, observ_date: ~D[2024-06-01])

      assert Birding.next_empty_date(user) == Date.utc_today()
    end
  end

  describe "new_observation/0" do
    test "returns a new observation with defaults" do
      obs = Birding.new_observation()
      assert %Kjogvi.Birding.Observation{} = obs
      assert obs.voice == false
      assert obs.hidden == false
      assert obs.unreported == false
    end
  end

  describe "get_checklists/2" do
    test "returns paginated checklists for a user" do
      user = user_fixture()
      insert(:checklist, user: user, observ_date: ~D[2024-01-15])
      insert(:checklist, user: user, observ_date: ~D[2024-02-20])

      page = Birding.get_checklists(user, %{page: 1, page_size: 10})
      assert length(page.entries) == 2
    end

    test "does not return checklists from other users" do
      user = user_fixture()
      other_user = user_fixture()
      insert(:checklist, user: user)
      insert(:checklist, user: other_user)

      page = Birding.get_checklists(user, %{page: 1, page_size: 10})
      assert length(page.entries) == 1
    end

    test "orders checklists by date descending" do
      user = user_fixture()
      insert(:checklist, user: user, observ_date: ~D[2024-01-15])
      insert(:checklist, user: user, observ_date: ~D[2024-03-20])
      insert(:checklist, user: user, observ_date: ~D[2024-02-10])

      page = Birding.get_checklists(user, %{page: 1, page_size: 10})
      dates = Enum.map(page.entries, & &1.observ_date)
      assert dates == [~D[2024-03-20], ~D[2024-02-10], ~D[2024-01-15]]
    end

    test "includes observation count" do
      user = user_fixture()
      checklist = insert(:checklist, user: user)
      insert(:observation, checklist: checklist, taxon_key: "ebird/eBird_2023/bkcchi1")
      insert(:observation, checklist: checklist, taxon_key: "ebird/eBird_2023/amecro")

      page = Birding.get_checklists(user, %{page: 1, page_size: 10})
      assert hd(page.entries).observation_count == 2
    end

    test "includes distinct taxa count" do
      user = user_fixture()
      checklist = insert(:checklist, user: user)
      insert(:observation, checklist: checklist, taxon_key: "ebird/eBird_2023/amecro")
      insert(:observation, checklist: checklist, taxon_key: "ebird/eBird_2023/amecro")
      insert(:observation, checklist: checklist, taxon_key: "ebird/eBird_2023/bkcchi1")

      page = Birding.get_checklists(user, %{page: 1, page_size: 10})
      entry = hd(page.entries)
      assert entry.observation_count == 3
      assert entry.taxa_count == 2
    end

    test "includes countable species count from species/taxa mapping" do
      user = user_fixture()
      {taxon, _page} = Kjogvi.Factory.create_species_taxon_with_page()
      key = Ornitho.Schema.Taxon.key(taxon)

      checklist = insert(:checklist, user: user)
      insert(:observation, checklist: checklist, taxon_key: key)
      # Same taxon again — counts once as a species.
      insert(:observation, checklist: checklist, taxon_key: key)
      # A taxon with no species page is not countable.
      insert(:observation, checklist: checklist, taxon_key: "ebird/eBird_2023/unmapped")

      page = Birding.get_checklists(user, %{page: 1, page_size: 10})
      entry = hd(page.entries)
      assert entry.species_count == 1
      assert entry.taxa_count == 2
    end

    test "excludes unreported observations from species count" do
      user = user_fixture()
      {taxon, _page} = Kjogvi.Factory.create_species_taxon_with_page()
      key = Ornitho.Schema.Taxon.key(taxon)

      checklist = insert(:checklist, user: user)
      insert(:observation, checklist: checklist, taxon_key: key, unreported: true)

      page = Birding.get_checklists(user, %{page: 1, page_size: 10})
      entry = hd(page.entries)
      assert entry.species_count == 0
      assert entry.observation_count == 1
    end

    test "returns zero counts for a checklist with no observations" do
      user = user_fixture()
      insert(:checklist, user: user)

      page = Birding.get_checklists(user, %{page: 1, page_size: 10})
      entry = hd(page.entries)
      assert entry.observation_count == 0
      assert entry.taxa_count == 0
      assert entry.species_count == 0
    end

    test "paginates results" do
      user = user_fixture()

      for i <- 1..5 do
        insert(:checklist, user: user, observ_date: Date.add(~D[2024-01-01], i))
      end

      page = Birding.get_checklists(user, %{page: 1, page_size: 2})
      assert length(page.entries) == 2
      assert page.total_entries == 5
    end
  end

  describe "fetch_checklist_with_observations/2" do
    test "returns a checklist with preloaded observations for the user" do
      user = user_fixture()
      {taxon, _} = Kjogvi.Factory.create_species_taxon_with_page()
      checklist = insert(:checklist, user: user)
      insert(:observation, checklist: checklist, taxon_key: Ornitho.Schema.Taxon.key(taxon))

      fetched = Birding.fetch_checklist_with_observations(user, checklist.id)
      assert fetched.id == checklist.id
      assert length(fetched.observations) == 1
    end

    test "raises when checklist belongs to another user" do
      user = user_fixture()
      other_user = user_fixture()
      checklist = insert(:checklist, user: other_user)

      assert_raise Ecto.NoResultsError, fn ->
        Birding.fetch_checklist_with_observations(user, checklist.id)
      end
    end

    test "raises when checklist does not exist" do
      user = user_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Birding.fetch_checklist_with_observations(user, -1)
      end
    end
  end

  describe "fetch_checklist_for_edit/2" do
    test "returns a checklist with preloaded observations" do
      user = user_fixture()
      checklist = insert(:checklist, user: user)
      insert(:observation, checklist: checklist, taxon_key: "ebird/eBird_2023/bkcchi1")

      fetched = Birding.fetch_checklist_for_edit(user, checklist.id)
      assert fetched.id == checklist.id
      assert length(fetched.observations) == 1
    end

    test "raises when checklist belongs to another user" do
      user = user_fixture()
      other_user = user_fixture()
      checklist = insert(:checklist, user: other_user)

      assert_raise Ecto.NoResultsError, fn ->
        Birding.fetch_checklist_for_edit(user, checklist.id)
      end
    end
  end

  describe "checklist_deletable?/1" do
    test "true when observation_count virtual field is zero" do
      assert Birding.checklist_deletable?(%Checklist{observation_count: 0})
    end

    test "false when observation_count virtual field is positive" do
      refute Birding.checklist_deletable?(%Checklist{observation_count: 2})
    end

    test "true when preloaded observations are empty" do
      assert Birding.checklist_deletable?(%Checklist{observations: []})
    end

    test "false when preloaded observations are present" do
      refute Birding.checklist_deletable?(%Checklist{observations: [%Birding.Observation{}]})
    end

    test "queries the database when neither is loaded" do
      user = user_fixture()
      checklist = insert(:checklist, user: user)

      assert Birding.checklist_deletable?(%Checklist{id: checklist.id})

      insert(:observation, checklist: checklist, taxon_key: "ebird/eBird_2023/bkcchi1")
      refute Birding.checklist_deletable?(%Checklist{id: checklist.id})
    end
  end

  describe "delete_checklist/1" do
    test "deletes a checklist that has no observations" do
      user = user_fixture()
      checklist = insert(:checklist, user: user)

      assert {:ok, _checklist} = Birding.delete_checklist(checklist)
      refute Kjogvi.Repo.get(Checklist, checklist.id)
    end

    test "refuses to delete a checklist with observations" do
      user = user_fixture()
      checklist = insert(:checklist, user: user)
      insert(:observation, checklist: checklist, taxon_key: "ebird/eBird_2023/bkcchi1")

      assert {:error, :has_observations} = Birding.delete_checklist(checklist)
      assert Kjogvi.Repo.get(Checklist, checklist.id)
    end
  end
end
