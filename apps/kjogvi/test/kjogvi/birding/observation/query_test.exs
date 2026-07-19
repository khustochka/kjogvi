defmodule Kjogvi.Birding.Observation.QueryTest do
  use Kjogvi.DataCase, async: true

  import Kjogvi.AccountsFixtures

  alias Kjogvi.Birding.Observation.Query

  defp observation_for(user, attrs \\ []) do
    checklist =
      Kjogvi.Factory.insert(
        :checklist,
        [user: user, location: Kjogvi.Factory.insert(:location)] ++
          Keyword.take(attrs, [:observ_date])
      )

    Kjogvi.Factory.insert(
      :observation,
      [checklist: checklist, taxon_key: "mallar1"] ++ Keyword.take(attrs, [:taxon_key])
    )
  end

  describe "owned_by/2" do
    test "restricts to the user's own observations" do
      user = user_fixture()
      other = user_fixture()
      mine = observation_for(user)
      _theirs = observation_for(other)

      ids =
        Query.with_checklist()
        |> Query.owned_by(user)
        |> Repo.all()
        |> Enum.map(& &1.id)

      assert ids == [mine.id]
    end

    test "accepts a bare user id" do
      user = user_fixture()
      mine = observation_for(user)
      _theirs = observation_for(user_fixture())

      ids =
        Query.with_checklist()
        |> Query.owned_by(user.id)
        |> Repo.all()
        |> Enum.map(& &1.id)

      assert ids == [mine.id]
    end
  end

  describe "with_ids/2" do
    test "restricts to the given ids" do
      user = user_fixture()
      wanted = observation_for(user)
      _other = observation_for(user)

      ids =
        Query.with_checklist()
        |> Query.with_ids([wanted.id])
        |> Repo.all()
        |> Enum.map(& &1.id)

      assert ids == [wanted.id]
    end
  end

  describe "with_taxon_keys/2" do
    test "restricts to the given taxon keys" do
      user = user_fixture()
      mallard = observation_for(user, taxon_key: "mallar1")
      _other = observation_for(user, taxon_key: "cangoo")

      ids =
        Query.with_checklist()
        |> Query.with_taxon_keys(["mallar1"])
        |> Repo.all()
        |> Enum.map(& &1.id)

      assert ids == [mallard.id]
    end
  end

  describe "on_checklist/2" do
    test "restricts to the given checklist" do
      user = user_fixture()
      wanted = observation_for(user)
      _other = observation_for(user)

      ids =
        Query.with_checklist()
        |> Query.on_checklist(wanted.checklist_id)
        |> Repo.all()
        |> Enum.map(& &1.id)

      assert ids == [wanted.id]
    end
  end

  describe "on_date/2" do
    test "restricts to observations on checklists of that date" do
      user = user_fixture()
      wanted = observation_for(user, observ_date: ~D[2024-05-01])
      _other = observation_for(user, observ_date: ~D[2024-06-01])

      ids =
        Query.with_checklist()
        |> Query.on_date(~D[2024-05-01])
        |> Repo.all()
        |> Enum.map(& &1.id)

      assert ids == [wanted.id]
    end
  end

  describe "limit_to/2" do
    test "caps the number of results" do
      user = user_fixture()
      observation_for(user)
      observation_for(user)

      results =
        Query.with_checklist()
        |> Query.limit_to(1)
        |> Repo.all()

      assert length(results) == 1
    end
  end

  describe "newest_checklist_first/1" do
    test "orders by checklist date descending" do
      user = user_fixture()
      older = observation_for(user, observ_date: ~D[2024-05-01])
      newer = observation_for(user, observ_date: ~D[2024-06-01])

      ids =
        Query.with_checklist()
        |> Query.newest_checklist_first()
        |> Repo.all()
        |> Enum.map(& &1.id)

      assert ids == [newer.id, older.id]
    end
  end

  describe "with_checklist/0" do
    test "does not apply the reportability filter of base_for_scope/1" do
      user = user_fixture()

      checklist =
        Kjogvi.Factory.insert(:checklist, user: user, location: Kjogvi.Factory.insert(:location))

      unreported =
        Kjogvi.Factory.insert(:observation,
          checklist: checklist,
          taxon_key: "mallar1",
          unreported: true
        )

      ids = Query.with_checklist() |> Repo.all() |> Enum.map(& &1.id)

      assert ids == [unreported.id]
    end
  end
end
