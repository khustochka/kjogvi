defmodule Kjogvi.Legacy.ImportTest do
  # Not async: swaps the global legacy import adapter config.
  use Kjogvi.DataCase, async: false

  alias Kjogvi.Legacy.Import
  alias Kjogvi.Repo

  defmodule EmptyAdapter do
    @moduledoc false
    def init, do: nil
    def fetch_page(_object_type, _fetcher, _page), do: %{columns: [], rows: []}
  end

  defp insert_legacy_book do
    [slug, version] = String.split(Import.book_signature(), "/")
    Ornitho.Factory.insert(:book, slug: slug, version: version)
  end

  describe "run/2" do
    test "returns {:error, %{message: _}} when the legacy taxonomy is not loaded" do
      user = Kjogvi.AccountsFixtures.user_fixture()

      assert {:error, %{message: message}} = Import.run(user)
      assert message =~ Import.book_signature()
    end

    test "does not truncate data when validation fails" do
      user = Kjogvi.AccountsFixtures.user_fixture()
      checklist = insert(:checklist)

      {:error, _} = Import.run(user)

      assert Repo.get(Kjogvi.Birding.Checklist, checklist.id)
    end

    test "switches the user's default taxonomy to the legacy book" do
      insert_legacy_book()

      config = Import.config()
      Application.put_env(:kjogvi, Import, Keyword.put(config, :adapter, EmptyAdapter))
      on_exit(fn -> Application.put_env(:kjogvi, Import, config) end)

      user = Kjogvi.AccountsFixtures.user_fixture(%{default_book_signature: "ebird/v2025"})

      assert {:ok, _} = Import.run(user)

      assert Kjogvi.Accounts.get_user!(user.id).default_book_signature ==
               Import.book_signature()
    end
  end
end
