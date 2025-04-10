defmodule Kjogvi.Repo.Migrations.AddExtrasToUsers do
  use Ecto.Migration

  def change do
    alter table("users") do
      add :extras, :map, default: "{}"
    end
  end
end
