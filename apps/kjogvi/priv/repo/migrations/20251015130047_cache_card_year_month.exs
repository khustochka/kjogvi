defmodule Kjogvi.Repo.Migrations.CacheCardYearMonth do
  use Ecto.Migration

  def change do
    alter table("cards") do
      add :cached_year, :integer, generated: "ALWAYS AS (EXTRACT(year FROM observ_date)) STORED"
      add :cached_month, :integer, generated: "ALWAYS AS (EXTRACT(month FROM observ_date)) STORED"
    end

    create index(:cards, :cached_year)
    create index(:cards, :cached_month)
  end
end
