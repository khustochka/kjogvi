defmodule KjogviWeb.Router do
  use KjogviWeb, :router

  import OrnithoWeb.Router
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {KjogviWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", KjogviWeb do
    pipe_through :browser

    get "/", PageController, :home

    live_dashboard "/dashboard", metrics: KjogviWeb.Telemetry
    ornitho_web("/taxonomy")
  end

  scope "/locations", KjogviWeb do
    pipe_through :browser

    live "/", LocationLive.Index, :index
  end

  scope "/cards", KjogviWeb do
    pipe_through :browser

    live "/", CardLive.Index, :index
    live "/page/:page", CardLive.Index, :index, as: :card_page
    live "/:id", CardLive.Show, :show
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
