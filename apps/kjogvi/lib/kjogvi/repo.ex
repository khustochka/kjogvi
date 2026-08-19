defmodule Kjogvi.Repo do
  use Ecto.Repo,
    otp_app: :kjogvi,
    adapter: Ecto.Adapters.Postgres

  @doc """
  Runs page-based `Flop` pagination against a query, returning
  `{entries, %Flop.Meta{}}`.

  Ordering comes from the query itself, so callers pass only `:page` and
  `:page_size`.
  """
  def paginate(queryable, %{page: page, page_size: page_size}) do
    Flop.run(queryable, %Flop{page: page, page_size: page_size}, repo: __MODULE__)
  end
end
