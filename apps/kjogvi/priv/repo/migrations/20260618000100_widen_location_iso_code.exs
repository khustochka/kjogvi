defmodule Kjogvi.Repo.Migrations.WidenLocationIsoCode do
  use Ecto.Migration

  def change do
    # ISO 3166-2 codes (e.g. "US-CA") exceed the original 3-char limit.
    alter table(:locations) do
      modify :iso_code, :string, size: 16, from: {:string, size: 3}
    end
  end
end
