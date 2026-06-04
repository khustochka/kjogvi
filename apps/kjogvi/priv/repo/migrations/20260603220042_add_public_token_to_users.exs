defmodule Kjogvi.Repo.Migrations.AddPublicTokenToUsers do
  use Ecto.Migration

  import Ecto.Query

  alias Kjogvi.Repo
  alias Kjogvi.Util.Token

  def up do
    alter table(:users) do
      add :public_token, :string
    end

    flush()

    backfill_tokens()

    alter table(:users) do
      modify :public_token, :string, null: false
    end

    create unique_index(:users, [:public_token])
  end

  def down do
    drop index(:users, [:public_token])

    alter table(:users) do
      remove :public_token
    end
  end

  defp backfill_tokens do
    ids = Repo.all(from(u in "users", select: u.id))

    for id <- ids do
      Repo.update_all(
        from(u in "users", where: u.id == ^id),
        set: [public_token: Token.generate()]
      )
    end
  end
end
