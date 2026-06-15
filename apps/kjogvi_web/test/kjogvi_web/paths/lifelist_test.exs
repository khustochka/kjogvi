defmodule KjogviWeb.Paths.LifelistTest do
  use KjogviWeb.ConnCase, async: true

  import KjogviWeb.Paths.LifelistPath

  alias Kjogvi.Scope

  describe "lifelist_path/2 for the :community section" do
    setup do
      %{scope: %Scope{section: :community}}
    end

    test "no filter", %{scope: scope} do
      assert lifelist_path(scope) == "/community/lifelist"
    end

    test "year filter", %{scope: scope} do
      assert lifelist_path(scope, year: 2023) == "/community/lifelist/2023"
    end

    test "location filter", %{scope: scope} do
      location = insert(:location, slug: "ukraine")
      assert lifelist_path(scope, location: location) == "/community/lifelist/ukraine"
    end

    test "year and location filter", %{scope: scope} do
      location = insert(:location, slug: "ukraine")

      assert lifelist_path(scope, year: 2023, location: location) ==
               "/community/lifelist/2023/ukraine"
    end

    test "taxonomy sort is carried in the query", %{scope: scope} do
      assert lifelist_path(scope, sort: :taxonomy) == "/community/lifelist?sort=taxonomy"
    end
  end

  describe "lifelist_path/2 routes by section" do
    test "the :user section points to the public user URL space" do
      user = Kjogvi.AccountsFixtures.user_fixture()
      scope = %Scope{section: :user, subject_user: user}

      assert lifelist_path(scope) == "/users/#{user.nickname}/lifelist"
    end

    test "the :private section points to the /my URL space" do
      scope = %Scope{section: :private}

      assert lifelist_path(scope) == "/my/lifelist"
    end
  end
end
