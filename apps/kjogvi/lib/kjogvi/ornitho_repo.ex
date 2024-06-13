defmodule Kjogvi.OrnithoRepo do
  @moduledoc """
  Ornithologue repository.
  """

  use Ecto.Repo,
    otp_app: :kjogvi,
    adapter: Ecto.Adapters.Postgres

  use Scrivener
end
