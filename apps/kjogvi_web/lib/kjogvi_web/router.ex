defmodule KjogviWeb.Router do
  use KjogviWeb, :router

  import OrnithoWeb.Router
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  import Phoenix.LiveDashboard.Router

  import KjogviWeb.Plug

  pipeline :browser do
    plug :accepts, ["html"]
    plug :remove_trailing_slash
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {KjogviWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :lifelist do
    # plug :validate_lifelist_params
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", KjogviWeb do
    pipe_through :browser

    get "/", PageController, :home

    live_dashboard "/dashboard",
      metrics: KjogviWeb.Telemetry,
      env_keys: ["ECTO_IPV6", "PHX_HOST", "PHX_PORT", "DNS_CLUSTER_QUERY"]

    ornitho_web("/taxonomy")
  end

  scope "/locations", KjogviWeb do
    pipe_through :browser

    live "/", Live.Location.Index, :index
    live "/countries", Live.Country.Index, :index
  end

  scope "/cards", KjogviWeb do
    pipe_through :browser

    live "/", Live.Card.Index, :index
    live "/page/:page", Live.Card.Index, :index, as: :card_page
    live "/:id", Live.Card.Show, :show
  end

  scope "/lifelist", KjogviWeb do
    pipe_through :browser
    pipe_through :lifelist

    live "/", Live.Lifelist.Index, :index
    live "/:year_or_location", Live.Lifelist.Index, :index
    live "/:year/:location", Live.Lifelist.Index, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", KjogviWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:kjogvi_web, :dev_routes) do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
