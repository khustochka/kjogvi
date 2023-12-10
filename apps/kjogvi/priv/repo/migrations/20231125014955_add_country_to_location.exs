defmodule Kjogvi.Repo.Migrations.AddCountryToLocation do
  use Ecto.Migration

  def change do
    alter table("locations") do
      remove :cached_country_id
      # TODO: null: false
      add :country_id, references("locations", on_delete: :restrict)
    end
  end
end
