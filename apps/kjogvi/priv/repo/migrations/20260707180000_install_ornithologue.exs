defmodule Kjogvi.Repo.Migrations.InstallOrnithologue do
  use Ecto.Migration

  def up do
    Ornitho.Migrations.up(version: 1, prefix: "ornithologue")
  end

  def down do
    Ornitho.Migrations.down(version: 1, prefix: "ornithologue")
  end
end
