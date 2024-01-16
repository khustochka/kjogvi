defmodule Kjogvi.OrnithoRepo.Migrations.CreateOrnithologueTables do
  use Ecto.Migration

  def up do
    Ornitho.Migrations.up(version: 1)
  end

  def down do
    Ornitho.Migrations.down(version: 1)
  end
end
