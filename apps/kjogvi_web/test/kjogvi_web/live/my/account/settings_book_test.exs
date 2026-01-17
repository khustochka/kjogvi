defmodule KjogviWeb.Live.My.Account.SettingsBookTest do
  use KjogviWeb.ConnCase, async: true

  alias Kjogvi.UsersFixtures
  alias Kjogvi.Repo

  test "user can select default book and it is saved", %{conn: conn} do
    # insert a book into Ornitho repo via factory
    book = Ornitho.Factory.insert(:book)

    user = UsersFixtures.user_fixture()
    token = Kjogvi.Users.generate_user_session_token(user)

    conn =
      conn |> Phoenix.ConnTest.init_test_session(%{}) |> Plug.Conn.put_session(:user_token, token)

    # Simulate the controller action directly
    post(conn, "/my/account/settings", %{
      "user" => %{"default_book_signature" => "#{book.slug}/#{book.version}"},
      "email" => "test@example.com",
      "password" => "secret"
    })

    # Reload user from DB and assert it's saved
    user = Repo.get!(Kjogvi.Users.User, user.id)
    assert user.default_book_signature == "#{book.slug}/#{book.version}"
  end
end
