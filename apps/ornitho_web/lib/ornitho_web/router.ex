defmodule OrnithoWeb.Router do
  use OrnithoWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OrnithoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers,
      %{"content-security-policy-report-only" =>
      "default-src 'self' https:; img-src 'self' https: data:; font-src 'self' https: data:"}
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", OrnithoWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/taxonomy", OrnithoWeb do
    pipe_through :browser

    get "/", BooksController, :index
    live "/:slug/:version", BookLive.Show
    live "/:slug/:version/page/:page", BookLive.Show
    live "/:slug/:version/:code", TaxaLive.Show
  end

  # Other scopes may use custom stacks.
  # scope "/api", OrnithoWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:ornitho_web, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: OrnithoWeb.Telemetry
    end
  end
end
