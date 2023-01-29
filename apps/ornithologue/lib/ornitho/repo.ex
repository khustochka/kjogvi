defmodule Ornitho.Repo do
  use Ecto.Repo,
    otp_app: :ornithologue,
    adapter: Ecto.Adapters.Postgres
end
