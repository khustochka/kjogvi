# OrnithoWeb

OrnithoWeb is the dashboard UI for Ornithologue application.

## Usage

LiveView should be configured in your app.

Add to your router:

```elixir
# lib/my_app_web/router.ex
use MyAppWeb, :router
import OrnithoWeb.Router

...

scope "/" do
  pipe_through :browser
  ornitho_web "/taxonomy"
end
```

Do not forget to protect your app with authentication.

## Development

Run:

    $ mix setup
    $ mix dev

You can also run via `iex`:

    $ iex -S mix dev

### Environment variables:

* `PG_URL`: Postgres database URL
* `PG_DATABASE`: Database name

## Acknowledgements

This project is heavily based on techniques adopted/copied from [phoenix_live_dashboard](https://github.com/phoenixframework/phoenix_live_dashboard).
