defmodule Kjogvi.Repo do
  use Ecto.Repo,
    otp_app: :kjogvi,
    adapter: Ecto.Adapters.Postgres

  use Scrivener
end
