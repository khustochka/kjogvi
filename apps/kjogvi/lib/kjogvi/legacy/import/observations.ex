defmodule Kjogvi.Legacy.Import.Observations do
  @moduledoc false

  alias Kjogvi.Repo
  alias Kjogvi.Birding.Observation
  alias Ornitho.Schema.Taxon

  import Ecto.Query

  def import(columns_str, rows, _opts) do
    columns = columns_str |> Enum.map(&String.to_atom/1)

    obs =
      for row <- rows do
        Enum.zip(columns, row)
        |> Map.new()
        |> transform_keys
      end

    _ = Repo.insert_all(Kjogvi.Birding.Observation, obs)

    Repo.query!("SELECT setval('observations_id_seq', (SELECT MAX(id) FROM observations));")

    keys =
      Observation
      |> distinct([:taxon_key])
      |> Repo.all()
      |> Enum.map(& &1.taxon_key)

    taxa = Ornithologue.get_taxa_and_species(keys)

    for {key, taxon} <- taxa, not is_nil(taxon.parent_species) or taxon.category == "species" do
      species_key =
        if taxon.category == "species" do
          key
        else
          Taxon.key(taxon.parent_species)
        end

      Observation
      |> where(taxon_key: ^key)
      |> Repo.update_all(set: [cached_species_key: species_key])
    end
  end

  def truncate do
    _ = Repo.query!("TRUNCATE observations;")
    _ = Repo.query!("ALTER SEQUENCE observations_id_seq RESTART;")
  end

  defp transform_keys(%{ebird_code: "unrepbirdsp"} = obs) do
    %{obs | ebird_code: "bird1"}
    |> Map.put(:unreported, true)
    |> transform_keys
  end

  defp transform_keys(
         %{created_at: created_at, updated_at: updated_at, ebird_code: ebird_code} = obs
       ) do
    obs
    |> Map.drop([:created_at, :post_id, :taxon_id, :ebird_code])
    |> Map.put(:taxon_key, "/ebird/v2024/#{ebird_code}")
    |> Map.put(:inserted_at, convert_timestamp(created_at))
    |> Map.put(:updated_at, convert_timestamp(updated_at))
  end

  defp convert_timestamp(nil) do
    nil
  end

  defp convert_timestamp(%NaiveDateTime{} = time) do
    {:ok, converted} = DateTime.from_naive(time, "Etc/UTC")
    converted
  end

  defp convert_timestamp(time) when is_binary(time) do
    {:ok, dt, _} = DateTime.from_iso8601(time)
    {usec, _} = dt.microsecond
    %{dt | microsecond: {usec, 6}}
  end
end
