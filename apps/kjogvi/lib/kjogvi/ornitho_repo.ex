defmodule Kjogvi.OrnithoRepo do
  use Ecto.Repo,
    otp_app: :kjogvi,
    adapter: Ecto.Adapters.Postgres

  use Scrivener
end
