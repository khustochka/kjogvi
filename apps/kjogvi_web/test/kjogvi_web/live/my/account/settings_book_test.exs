defmodule KjogviWeb.Live.My.Account.SettingsBookTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Kjogvi.AccountsFixtures
  alias Kjogvi.Repo

  test "user can select default book and it is saved", %{conn: conn} do
    # insert a book into Ornitho repo via factory
    book = Ornitho.Factory.insert(:book)

    user = AccountsFixtures.user_fixture()
    token = Kjogvi.Accounts.generate_user_session_token(user)

    conn =
      conn |> Phoenix.ConnTest.init_test_session(%{}) |> Plug.Conn.put_session(:user_token, token)

    {:ok, lv, _html} = live(conn, ~p"/my/account/settings")

    lv
    |> form("#settings_form", %{
      "user" => %{
        "nickname" => user.nickname,
        "default_book_signature" => "#{book.slug}/#{book.version}"
      }
    })
    |> render_submit()

    # Reload user from DB and assert it's saved
    user = Repo.get!(Kjogvi.Accounts.User, user.id)
    assert user.default_book_signature == "#{book.slug}/#{book.version}"
  end
end
