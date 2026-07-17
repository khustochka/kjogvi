defmodule Kjogvi.Repo.Migrations.InstallOban do
  use Ecto.Migration

  def up do
    Oban.Migration.up(prefix: "oban")
  end

  def down do
    Oban.Migration.down(version: 1, prefix: "oban")
  end
end
