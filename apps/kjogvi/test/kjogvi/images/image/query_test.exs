defmodule Kjogvi.Images.Image.QueryTest do
  use Kjogvi.DataCase, async: true

  alias Kjogvi.Images.Image.Query

  describe "base/0" do
    test "preloads the owning user" do
      user = Kjogvi.AccountsFixtures.user_fixture()
      Kjogvi.ImagesFixtures.image_fixture(user: user)

      [image] = Repo.all(Query.base())

      assert image.user.id == user.id
    end
  end

  describe "for_user/2" do
    test "restricts to the user's own images" do
      user = Kjogvi.AccountsFixtures.user_fixture()
      mine = Kjogvi.ImagesFixtures.image_fixture(user: user)
      _theirs = Kjogvi.ImagesFixtures.image_fixture()

      ids =
        Query.base()
        |> Query.for_user(user)
        |> Repo.all()
        |> Enum.map(& &1.id)

      assert ids == [mine.id]
    end
  end

  describe "newest_first/1" do
    test "orders by insertion time descending" do
      user = Kjogvi.AccountsFixtures.user_fixture()
      first = Kjogvi.ImagesFixtures.image_fixture(user: user)
      second = Kjogvi.ImagesFixtures.image_fixture(user: user)

      ids =
        Query.base()
        |> Query.for_user(user)
        |> Query.newest_first()
        |> Repo.all()
        |> Enum.map(& &1.id)

      assert ids == [second.id, first.id]
    end
  end
end
