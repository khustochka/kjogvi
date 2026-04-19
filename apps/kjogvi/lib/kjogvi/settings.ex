defmodule Kjogvi.Settings do
  @moduledoc """
  Site settings.
  """

  @prefix "settings:"
  @main_user_key "main_user"

  import Ecto.Query

  alias Kjogvi.Repo
  alias Kjogvi.Users

  def main_user() do
    Kjogvi.Cache.fetch(key(@main_user_key), fn _ ->
      case get_main_user() do
        nil -> {:ignore, nil}
        user -> {:commit, user}
      end
    end)
  end

  @doc """
  Evicts the cached main user. Call this after updating any field on the main
  user that is projected into the cached record (see `get_main_user/0`), so
  subsequent reads see the new value.
  """
  def invalidate_main_user() do
    Kjogvi.Cache.delete(key(@main_user_key))
  end

  defp get_main_user() do
    Users.main_user_query()
    |> select([u], %{
      id: u.id,
      extras: fragment("jsonb_build_object('log_settings', ?->'log_settings')", u.extras)
    })
    |> Repo.one()
    |> case do
      nil -> nil
      row -> Repo.load(Users.User, row)
    end
  end

  defp key(key), do: @prefix <> key
end
