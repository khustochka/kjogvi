defmodule Kjogvi.Repo.Migrations.AddNicknameToUsers do
  use Ecto.Migration

  import Ecto.Query

  alias Kjogvi.Repo

  @nickname_alphabet ~c"abcdefghijklmnopqrstuvwxyz0123456789"

  def up do
    alter table(:users) do
      add :nickname, :string
      add :display_name, :string
    end

    flush()

    backfill_nicknames()

    alter table(:users) do
      modify :nickname, :string, null: false
    end

    create unique_index(:users, [:nickname])
  end

  def down do
    drop index(:users, [:nickname])

    alter table(:users) do
      remove :display_name
      remove :nickname
    end
  end

  defp backfill_nicknames do
    ids = Repo.all(from(u in "users", select: u.id))

    for id <- ids do
      Repo.update_all(
        from(u in "users", where: u.id == ^id),
        set: [nickname: random_nickname()]
      )
    end
  end

  defp random_nickname do
    for _ <- 1..10, into: "", do: <<Enum.random(@nickname_alphabet)>>
  end
end
