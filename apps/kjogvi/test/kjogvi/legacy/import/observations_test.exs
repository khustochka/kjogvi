defmodule Kjogvi.Legacy.Import.ObservationsTest do
  # Not async: `Observations.import/3` calls `setval('observations_id_seq', ...)`,
  # a non-transactional, database-global side effect the SQL sandbox cannot
  # roll back or isolate. See Kjogvi.Legacy.Import.CardsTest for details.
  use Kjogvi.DataCase, async: false

  import Kjogvi.Factory

  alias Kjogvi.Legacy.Import.Observations
  alias Kjogvi.Birding.Observation
  alias Kjogvi.Repo

  describe "import/3" do
    test "builds taxon_key from the user's default_book_signature" do
      user =
        Kjogvi.AccountsFixtures.user_fixture()
        |> Ecto.Changeset.change(default_book_signature: "ebird/v2025")
        |> Repo.update!()

      checklist = insert(:checklist, user: user)

      now = "2026-01-02T03:04:05Z"

      Observations.import(
        ["card_id", "ebird_code", "created_at", "updated_at"],
        [[checklist.id, "amerob", now, now]],
        user: user
      )

      [obs] = Repo.all(Observation)
      assert obs.taxon_key == "/ebird/v2025/amerob"
    end

    test "marks imported observations with the :legacy import source" do
      user =
        Kjogvi.AccountsFixtures.user_fixture()
        |> Ecto.Changeset.change(default_book_signature: "ebird/v2025")
        |> Repo.update!()

      checklist = insert(:checklist, user: user)

      now = "2026-01-02T03:04:05Z"

      Observations.import(
        ["card_id", "ebird_code", "created_at", "updated_at"],
        [[checklist.id, "amerob", now, now]],
        user: user
      )

      [obs] = Repo.all(Observation)
      assert obs.import_source == :legacy
    end

    test "normalizes blank text columns to nil" do
      user =
        Kjogvi.AccountsFixtures.user_fixture()
        |> Ecto.Changeset.change(default_book_signature: "ebird/v2025")
        |> Repo.update!()

      checklist = insert(:checklist, user: user)

      now = "2026-01-02T03:04:05Z"

      Observations.import(
        ["card_id", "ebird_code", "created_at", "updated_at", "quantity", "notes"],
        [[checklist.id, "amerob", now, now, "  ", "  kept  "]],
        user: user
      )

      [obs] = Repo.all(Observation)
      assert obs.quantity == nil
      assert obs.notes == "kept"
    end

    test "raises when user has no default_book_signature" do
      user = Kjogvi.AccountsFixtures.user_fixture()

      assert_raise ArgumentError, ~r/default_book_signature/, fn ->
        Observations.import(
          ["card_id", "ebird_code", "created_at", "updated_at"],
          [[1, "amerob", "2026-01-02T03:04:05Z", "2026-01-02T03:04:05Z"]],
          user: user
        )
      end
    end

    test "raises when no :user option is provided" do
      assert_raise ArgumentError, ~r/requires a :user option/, fn ->
        Observations.import(
          ["card_id", "ebird_code", "created_at", "updated_at"],
          [[1, "amerob", "2026-01-02T03:04:05Z", "2026-01-02T03:04:05Z"]],
          []
        )
      end
    end

    test "falls back to the checklist's timestamps when created_at/updated_at are nil" do
      user =
        Kjogvi.AccountsFixtures.user_fixture()
        |> Ecto.Changeset.change(default_book_signature: "ebird/v2025")
        |> Repo.update!()

      card_time = ~U[2020-05-06 07:08:09.000000Z]

      checklist =
        insert(:checklist, user: user)
        |> Ecto.Changeset.change(inserted_at: card_time, updated_at: card_time)
        |> Repo.update!()

      Observations.import(
        ["card_id", "ebird_code", "created_at", "updated_at"],
        [[checklist.id, "amerob", nil, nil]],
        user: user
      )

      [obs] = Repo.all(Observation)
      assert obs.inserted_at == card_time
      assert obs.updated_at == card_time
    end

    test "keeps the observation's own timestamps when present" do
      user =
        Kjogvi.AccountsFixtures.user_fixture()
        |> Ecto.Changeset.change(default_book_signature: "ebird/v2025")
        |> Repo.update!()

      card_time = ~U[2020-05-06 07:08:09.000000Z]

      checklist =
        insert(:checklist, user: user)
        |> Ecto.Changeset.change(inserted_at: card_time, updated_at: card_time)
        |> Repo.update!()

      obs_time = "2026-01-02T03:04:05Z"

      Observations.import(
        ["card_id", "ebird_code", "created_at", "updated_at"],
        [[checklist.id, "amerob", obs_time, obs_time]],
        user: user
      )

      [obs] = Repo.all(Observation)
      assert obs.inserted_at == ~U[2026-01-02 03:04:05.000000Z]
      assert obs.updated_at == ~U[2026-01-02 03:04:05.000000Z]
    end
  end
end
