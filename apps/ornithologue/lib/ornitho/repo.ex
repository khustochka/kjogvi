defmodule Ornitho.Repo do
  @moduledoc """
  Facade over the host-configured repo (`config :ornithologue, repo: ...`).

  All Ornithologue database access goes through this module so that the
  configured `:prefix` (Postgres schema) is applied to every operation.
  Explicitly passed options win over the configured prefix.
  """

  def all(queryable, opts \\ []) do
    repo().all(queryable, default_opts(opts))
  end

  def one(queryable, opts \\ []) do
    repo().one(queryable, default_opts(opts))
  end

  def one!(queryable, opts \\ []) do
    repo().one!(queryable, default_opts(opts))
  end

  def exists?(queryable, opts \\ []) do
    repo().exists?(queryable, default_opts(opts))
  end

  def preload(structs_or_struct_or_nil, preloads, opts \\ []) do
    repo().preload(structs_or_struct_or_nil, preloads, default_opts(opts))
  end

  def insert(struct_or_changeset, opts \\ []) do
    repo().insert(struct_or_changeset, default_opts(opts))
  end

  def insert!(struct_or_changeset, opts \\ []) do
    repo().insert!(struct_or_changeset, default_opts(opts))
  end

  def update(changeset, opts \\ []) do
    repo().update(changeset, default_opts(opts))
  end

  def delete_all(queryable, opts \\ []) do
    repo().delete_all(queryable, default_opts(opts))
  end

  def insert_all(schema_or_source, entries_or_query, opts \\ []) do
    repo().insert_all(schema_or_source, entries_or_query, default_opts(opts))
  end

  def transaction(fun_or_multi, opts \\ []) do
    repo().transaction(fun_or_multi, opts)
  end

  def transact(fun_or_multi, opts \\ []) do
    repo().transact(fun_or_multi, opts)
  end

  def query(sql, params \\ [], opts \\ []) do
    repo().query(sql, params, opts)
  end

  def paginate(queryable, opts \\ []) do
    case Ornithologue.prefix() do
      nil ->
        repo().paginate(queryable, opts)

      prefix ->
        repo_opts = Keyword.put_new(opts[:options] || [], :prefix, prefix)
        repo().paginate(queryable, Keyword.put(opts, :options, repo_opts))
    end
  end

  @doc """
  Merges the configured prefix into a repo options list; explicit options win.
  Needed where options must be attached per operation, e.g. `Ecto.Multi.insert/4`.
  """
  def default_opts(opts \\ []) do
    case Ornithologue.prefix() do
      nil -> opts
      prefix -> Keyword.put_new(opts, :prefix, prefix)
    end
  end

  @doc """
  Table name qualified with the configured prefix, for raw SQL.

      qualified("taxa")
      #=> ~s("taxa") or ~s("ornitho"."taxa")
  """
  def qualified(table) do
    case Ornithologue.prefix() do
      nil -> ~s("#{table}")
      prefix -> ~s("#{prefix}"."#{table}")
    end
  end

  defp repo() do
    Ornithologue.repo()
  end
end
