defmodule Kjogvi.Settings do
  @moduledoc """
  Site settings.
  """

  @prefix "settings:"
  @main_user_key "main_user"

  import Ecto.Query

  alias Kjogvi.Users
  alias Kjogvi.Repo

  def main_user() do
    Kjogvi.Cache.fetch(key(@main_user_key), fn _ ->
      case get_main_user() do
        nil -> {:ignore, nil}
        user -> {:commit, user}
      end
    end)
  end

  defp get_main_user() do
    Users.admins()
    |> select([u], %{
      id: u.id,
      extras: fragment("jsonb_build_object('log_settings', ?->'log_settings')", u.extras)
    })
    |> first()
    |> Repo.one()
    |> case do
      nil -> nil
      row -> Repo.load(Kjogvi.Users.User, row)
    end
  end

  defp key(key), do: @prefix <> key
end
