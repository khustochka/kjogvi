defmodule Kjogvi.Repo.Migrations.CreateUserProfiles do
  use Ecto.Migration

  def change do
    create table(:user_profiles) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :about, :text
      add :country, :string
      add :ebird_profile_url, :string
      add :website_url, :string
      add :birding_since, :integer

      timestamps()
    end

    create unique_index(:user_profiles, [:user_id])
  end
end
