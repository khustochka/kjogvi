defmodule Kjogvi.Accounts.UserTest do
  use ExUnit.Case, async: true

  alias Kjogvi.Accounts.User

  describe "owns?/2" do
    test "true when the user's id matches the record's user_id" do
      assert User.owns?(%User{id: 1}, %{user_id: 1})
    end

    test "false when the ids differ" do
      refute User.owns?(%User{id: 1}, %{user_id: 2})
    end

    test "false for an unowned record" do
      refute User.owns?(%User{id: 1}, %{user_id: nil})
    end

    test "false when there is no user" do
      refute User.owns?(nil, %{user_id: 1})
    end
  end
end
