defmodule Ornitho.Migrations do
  @moduledoc """
  Migrations for Ornithologue.
  """

  use Ecto.Migration

  @first_version 1
  @latest_version 1

  @doc false
  def first_version do
    @first_version
  end

  @doc false
  def latest_version do
    @latest_version
  end

  @doc "Migrate up"
  def up(opts) do
    version = opts[:version] || @latest_version
    current = current_version()

    cond do
      current == 0 ->
        change(@first_version..version, :up)

      current < opts.version ->
        change((current + 1)..version, :up)

      true ->
        :ok
    end
  end

  @doc "Migrate down"
  def down(opts) do
    version = opts[:version] || @latest_version
    current = max(current_version(), @first_version)

    if current >= version do
      change(current..version, :down)
    end
  end

  def current_version() do
    query = """
    SELECT EXISTS (
    SELECT FROM pg_catalog.pg_class c
    JOIN   pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE  n.nspname = 'public'
    AND    c.relname = 'ornitho_migrations'
    AND    c.relkind = 'r'    -- only tables
    );
    """

    case repo().query(query, [], log: false) do
      {:ok, %{rows: [[true]]}} -> read_current_version()
      _ -> 0
    end
  end

  defp read_current_version() do
    query = """
    SELECT version
    FROM ornitho_migrations
    LIMIT 1;
    """

    case repo().query(query, [], log: false) do
      {:ok, %{rows: [[version]]}} when is_binary(version) -> String.to_integer(version)
      _ -> 0
    end
  end

  defp change(range, direction) do
    for index <- range do
      pad_idx =
        index
        |> to_string()
        |> String.pad_leading(2, "0")

      [__MODULE__, "V#{pad_idx}"]
      |> Module.safe_concat()
      |> apply(direction, [])
    end

    case direction do
      :up -> record_current_version(Enum.max(range))
      :down -> record_current_version(Enum.min(range) - 1)
    end
  end

  defp record_current_version(0) do
    :ok
  end

  defp record_current_version(1 = version) do
    execute "INSERT INTO ornitho_migrations (version) VALUES ('#{version}')"
  end

  defp record_current_version(version) do
    execute "UPDATE ornitho_migrations SET version='#{version}'"
  end
end
