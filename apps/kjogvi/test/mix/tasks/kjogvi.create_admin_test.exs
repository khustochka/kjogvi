defmodule Mix.Tasks.Kjogvi.CreateAdminTest do
  use Kjogvi.DataCase, async: false

  alias Kjogvi.Accounts

  setup do
    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(Mix.Shell.IO) end)
  end

  test "creates an admin user and prints the password" do
    Mix.Tasks.Kjogvi.CreateAdmin.run(["admin@example.com"])

    assert_received {:mix_shell, :info, ["Admin user admin@example.com created."]}
    assert_received {:mix_shell, :info, ["Password: " <> password]}

    user = Accounts.get_user_by_email_and_password("admin@example.com", password)
    assert user
    assert Accounts.admin?(user)
  end

  test "raises with changeset errors for an invalid email" do
    assert_raise Mix.Error, ~r/email/, fn ->
      Mix.Tasks.Kjogvi.CreateAdmin.run(["not-an-email"])
    end
  end
end
