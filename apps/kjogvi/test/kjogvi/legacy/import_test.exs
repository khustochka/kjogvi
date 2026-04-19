defmodule Kjogvi.Legacy.ImportTest do
  use Kjogvi.DataCase, async: true

  alias Kjogvi.Legacy.Import
  alias Kjogvi.Repo

  describe "run/2" do
    test "returns {:error, %{message: _}} when user has no default_book_signature" do
      user = Kjogvi.UsersFixtures.user_fixture()

      assert {:error, %{message: message}} = Import.run(user)
      assert message =~ "default taxonomy"
    end

    test "does not truncate data when validation fails" do
      user = Kjogvi.UsersFixtures.user_fixture()
      card = insert(:card)

      {:error, _} = Import.run(user)

      assert Repo.get(Kjogvi.Birding.Card, card.id)
    end
  end
end
