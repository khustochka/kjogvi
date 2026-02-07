ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Kjogvi.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Kjogvi.OrnithoRepo, :manual)

# Prevent noisy errors from OpentelemetryPhoenix when using live_isolated/3,
# which sets router info to :not_mounted_at_router (not enumerable).
:telemetry.detach({OpentelemetryPhoenix, :live_view})
