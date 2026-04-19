defmodule Kjogvi.Legacy.Import.ObservationsTest do
  use Kjogvi.DataCase, async: true

  import Kjogvi.Factory

  alias Kjogvi.Legacy.Import.Observations
  alias Kjogvi.Birding.Observation
  alias Kjogvi.Repo

  describe "import/3" do
    test "builds taxon_key from the user's default_book_signature" do
      user =
        Kjogvi.UsersFixtures.user_fixture()
        |> Ecto.Changeset.change(default_book_signature: "ebird/v2025")
        |> Repo.update!()

      card = insert(:card, user: user)

      now = "2026-01-02T03:04:05Z"

      Observations.import(
        ["card_id", "ebird_code", "created_at", "updated_at"],
        [[card.id, "amerob", now, now]],
        user: user
      )

      [obs] = Repo.all(Observation)
      assert obs.taxon_key == "/ebird/v2025/amerob"
    end

    test "raises when user has no default_book_signature" do
      user = Kjogvi.UsersFixtures.user_fixture()

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
  end
end
