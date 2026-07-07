defmodule Ornitho.Migrations do
  @moduledoc """
  Migrations for Ornithologue.

  Call from a host migration:

      def up, do: Ornitho.Migrations.up(version: 1)
      def down, do: Ornitho.Migrations.down(version: 1)

  Accepts a `:prefix` option naming the database schema to install the tables
  into (created if missing). Defaults to the configured
  `config :ornithologue, prefix: ...`, so hosts normally don't pass it.
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
  def up(opts \\ []) do
    version = opts[:version] || @latest_version
    prefix = opts[:prefix] || Ornithologue.prefix()
    current = current_version(prefix)

    if prefix && current < version do
      execute(~s(CREATE SCHEMA IF NOT EXISTS "#{prefix}"))
    end

    cond do
      current == 0 ->
        change(@first_version..version, :up, prefix)

      current < version ->
        change((current + 1)..version, :up, prefix)

      true ->
        :ok
    end
  end

  @doc "Migrate down"
  def down(opts \\ []) do
    version = opts[:version] || @latest_version
    prefix = opts[:prefix] || Ornithologue.prefix()
    current = max(current_version(prefix), @first_version)

    if current >= version do
      change(current..version, :down, prefix)
    end
  end

  def current_version(prefix \\ nil) do
    query = """
    SELECT EXISTS (
    SELECT FROM pg_catalog.pg_class c
    JOIN   pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE  n.nspname = $1
    AND    c.relname = 'ornitho_migrations'
    AND    c.relkind = 'r'    -- only tables
    );
    """

    case repo().query(query, [prefix || "public"], log: false) do
      {:ok, %{rows: [[true]]}} -> read_current_version(prefix)
      _ -> 0
    end
  end

  defp read_current_version(prefix) do
    query = """
    SELECT version
    FROM #{migrations_table(prefix)}
    LIMIT 1;
    """

    case repo().query(query, [], log: false) do
      {:ok, %{rows: [[version]]}} when is_binary(version) -> String.to_integer(version)
      _ -> 0
    end
  end

  defp change(range, direction, prefix) do
    for index <- range do
      pad_idx =
        index
        |> to_string()
        |> String.pad_leading(2, "0")

      [__MODULE__, "V#{pad_idx}"]
      |> Module.safe_concat()
      |> apply(direction, [%{prefix: prefix}])
    end

    case direction do
      :up -> record_current_version(Enum.max(range), prefix)
      :down -> record_current_version(Enum.min(range) - 1, prefix)
    end
  end

  defp record_current_version(0, _prefix) do
    :ok
  end

  defp record_current_version(1 = version, prefix) do
    execute "INSERT INTO #{migrations_table(prefix)} (version) VALUES ('#{version}')"
  end

  defp record_current_version(version, prefix) do
    execute "UPDATE #{migrations_table(prefix)} SET version='#{version}'"
  end

  defp migrations_table(nil), do: "ornitho_migrations"
  defp migrations_table(prefix), do: ~s("#{prefix}"."ornitho_migrations")
end
