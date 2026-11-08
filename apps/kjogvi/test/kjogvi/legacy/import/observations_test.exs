defmodule Kjogvi.Legacy.Import.ObservationsTest do
  # Not async: `Observations.import/3` calls `setval('observations_id_seq', ...)`,
  # a non-transactional, database-global side effect the SQL sandbox cannot
  # roll back or isolate. See Kjogvi.Legacy.Import.ChecklistsTest for details.
  use Kjogvi.DataCase, async: false

  import Kjogvi.Factory

  alias Kjogvi.Legacy.Import.Observations
  alias Kjogvi.Birding.Observation
  alias Kjogvi.Repo

  describe "import/3" do
    test "builds taxon_key from the :book_signature option" do
      user = Kjogvi.AccountsFixtures.user_fixture()

      checklist = insert(:checklist, user: user)

      now = "2026-01-02T03:04:05Z"

      Observations.import(
        ["card_id", "ebird_code", "created_at", "updated_at"],
        [[checklist.id, "amerob", now, now]],
        user: user,
        book_signature: "ebird/v2026"
      )

      [obs] = Repo.all(Observation)
      assert obs.taxon_key == "/ebird/v2026/amerob"
    end

    test "marks imported observations with the :legacy import source" do
      user = Kjogvi.AccountsFixtures.user_fixture()

      checklist = insert(:checklist, user: user)

      now = "2026-01-02T03:04:05Z"

      Observations.import(
        ["card_id", "ebird_code", "created_at", "updated_at"],
        [[checklist.id, "amerob", now, now]],
        user: user,
        book_signature: "ebird/v2026"
      )

      [obs] = Repo.all(Observation)
      assert obs.import_source == :legacy
    end

    test "normalizes blank text columns to nil" do
      user = Kjogvi.AccountsFixtures.user_fixture()

      checklist = insert(:checklist, user: user)

      now = "2026-01-02T03:04:05Z"

      Observations.import(
        ["card_id", "ebird_code", "created_at", "updated_at", "quantity", "notes"],
        [[checklist.id, "amerob", now, now, "  ", "  kept  "]],
        user: user,
        book_signature: "ebird/v2026"
      )

      [obs] = Repo.all(Observation)
      assert obs.quantity == nil
      assert obs.notes == "kept"
    end

    test "falls back to the checklist's timestamps when created_at/updated_at are nil" do
      user = Kjogvi.AccountsFixtures.user_fixture()

      checklist_time = ~U[2020-05-06 07:08:09.000000Z]

      checklist =
        insert(:checklist, user: user)
        |> Ecto.Changeset.change(inserted_at: checklist_time, updated_at: checklist_time)
        |> Repo.update!()

      Observations.import(
        ["card_id", "ebird_code", "created_at", "updated_at"],
        [[checklist.id, "amerob", nil, nil]],
        user: user,
        book_signature: "ebird/v2026"
      )

      [obs] = Repo.all(Observation)
      assert obs.inserted_at == checklist_time
      assert obs.updated_at == checklist_time
    end

    test "keeps the observation's own timestamps when present" do
      user = Kjogvi.AccountsFixtures.user_fixture()

      checklist_time = ~U[2020-05-06 07:08:09.000000Z]

      checklist =
        insert(:checklist, user: user)
        |> Ecto.Changeset.change(inserted_at: checklist_time, updated_at: checklist_time)
        |> Repo.update!()

      obs_time = "2026-01-02T03:04:05Z"

      Observations.import(
        ["card_id", "ebird_code", "created_at", "updated_at"],
        [[checklist.id, "amerob", obs_time, obs_time]],
        user: user,
        book_signature: "ebird/v2026"
      )

      [obs] = Repo.all(Observation)
      assert obs.inserted_at == ~U[2026-01-02 03:04:05.000000Z]
      assert obs.updated_at == ~U[2026-01-02 03:04:05.000000Z]
    end
  end

  describe "after_import/1" do
    test "promotes the imported user's observed taxa, leaving other users' taxa alone" do
      book = Ornitho.Factory.insert(:book)
      taxon = Ornitho.Factory.insert(:taxon, book: book, category: "species")
      other_taxon = Ornitho.Factory.insert(:taxon, book: book, category: "species")
      key = Ornitho.Schema.Taxon.key(taxon)
      other_key = Ornitho.Schema.Taxon.key(other_taxon)

      user = Kjogvi.AccountsFixtures.user_fixture()
      other_user = Kjogvi.AccountsFixtures.user_fixture()
      insert(:observation, checklist: build(:checklist, user: user), taxon_key: key)
      insert(:observation, checklist: build(:checklist, user: other_user), taxon_key: other_key)

      refute Kjogvi.Pages.Species.from_taxon_key(key)

      assert :ok = Observations.after_import(user: user)

      assert Kjogvi.Pages.Species.from_taxon_key(key)
      refute Kjogvi.Pages.Species.from_taxon_key(other_key)
    end
  end
end
