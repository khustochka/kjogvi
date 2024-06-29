defmodule Kjogvi.Settings do
  @moduledoc """
  Site settings.
  """

  import Ecto.Query

  alias Kjogvi.Users
  alias Kjogvi.Repo

  def main_user() do
    Users.admins()
    |> select([:id])
    |> first()
    |> Repo.one()
  end
end
