defmodule Kjogvi.Accounts.User.Query do
  @moduledoc """
  Queries for Users.
  """

  import Ecto.Query

  alias Kjogvi.Accounts.User

  @doc """
  Orders users by nickname, ascending.
  """
  def order_by_nickname(query \\ User) do
    order_by(query, [u], asc: u.nickname)
  end

  @doc """
  Restricts `query` to users whose `nickname` or `display_name` contains `term`
  (case-insensitive). A blank term is a no-op.
  """
  def search(query \\ User, term)

  def search(query, term) when is_binary(term) do
    case String.trim(term) do
      "" ->
        query

      trimmed ->
        pattern = "%#{trimmed}%"

        where(
          query,
          [u],
          ilike(u.nickname, ^pattern) or ilike(u.display_name, ^pattern)
        )
    end
  end
end
