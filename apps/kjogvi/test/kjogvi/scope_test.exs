defmodule Kjogvi.ScopeTest do
  use Kjogvi.DataCase, async: true

  import Kjogvi.AccountsFixtures

  alias Kjogvi.Scope

  describe "subject_user/1" do
    test "returns the current user for the :private area" do
      user = user_fixture()
      scope = %Scope{current_user: user, area: :private}

      assert Scope.subject_user(scope) == user
    end

    test "returns the subject user for the :user area" do
      current_user = user_fixture()
      subject_user = user_fixture()

      scope = %Scope{current_user: current_user, area: :user, subject_user: subject_user}

      assert Scope.subject_user(scope) == subject_user
    end

    test "returns nil for the :community area" do
      assert Scope.subject_user(%Scope{area: :community}) == nil
    end

    test "returns nil for the :admin area (all users)" do
      user = user_fixture()
      scope = %Scope{current_user: user, area: :admin}

      assert Scope.subject_user(scope) == nil
    end
  end

  describe "visibility/1" do
    test "is :private for the :private and :admin areas" do
      assert Scope.visibility(%Scope{area: :private}) == :private
      assert Scope.visibility(%Scope{area: :admin}) == :private
    end

    test "is :public for the :user and :community areas" do
      assert Scope.visibility(%Scope{area: :user}) == :public
      assert Scope.visibility(%Scope{area: :community}) == :public
    end
  end
end
