defmodule Kjogvi.BirdingTest do
  use Kjogvi.DataCase, async: true

  import Kjogvi.UsersFixtures

  alias Kjogvi.Birding

  describe "find_new_checklists/2" do
    test "returns unreported checklists" do
      user = user_fixture()
      insert(:card, user: user, ebird_id: "S100803884")
      insert(:card, user: user, ebird_id: "S100803921")

      new_checklists = [%{ebird_id: "S100878702"}, %{ebird_id: "S100803921"}]

      assert Birding.find_new_checklists(user, new_checklists) ==
               [%{ebird_id: "S100878702"}]
    end
  end
end
