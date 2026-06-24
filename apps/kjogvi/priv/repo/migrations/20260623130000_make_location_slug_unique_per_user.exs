defmodule Kjogvi.Repo.Migrations.MakeLocationSlugUniquePerUser do
  use Ecto.Migration

  # Slugs are unique within an owner, not globally: two users may each have a
  # location slugged "home". A plain composite `(user_id, slug)` index leaves
  # common locations (`user_id IS NULL`) unguarded — Postgres treats NULLs as
  # distinct — so a partial index keeps common slugs globally unique.
  def change do
    drop unique_index(:locations, [:slug])

    create unique_index(:locations, [:user_id, :slug])

    create unique_index(:locations, [:slug],
             where: "user_id IS NULL",
             name: :locations_common_slug_index
           )
  end
end
