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
    |> select([:id])
    |> first()
    |> Repo.one()
  end

  defp key(key), do: @prefix <> key
end
