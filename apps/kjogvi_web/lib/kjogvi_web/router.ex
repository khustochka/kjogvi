defmodule KjogviWeb.Router do
  use KjogviWeb, :router

  import KjogviWeb.UserAuth

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
    plug :fetch_current_user
  end

  pipeline :admin do
    plug :require_authenticated_user
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
  end

  scope "/", KjogviWeb do
    pipe_through :browser
    pipe_through :admin

    live_dashboard "/dashboard",
      metrics: KjogviWeb.Telemetry,
      env_keys: ["ECTO_IPV6", "PHX_HOST", "PHX_PORT", "DNS_CLUSTER_QUERY"]

    ornitho_web("/taxonomy")
  end

  scope "/", KjogviWeb do
    pipe_through :browser
    pipe_through :admin

    live_session :current_user,
      on_mount: [{KjogviWeb.UserAuth, :mount_current_user}] do
      live "/locations", Live.Location.Index, :index
      live "/locations/countries", Live.Country.Index, :index

      live "/cards", Live.Card.Index, :index
      live "/cards/page/:page", Live.Card.Index, :index, as: :card_page
      live "/cards/:id", Live.Card.Show, :show
    end
  end

  scope "/lifelist", KjogviWeb do
    pipe_through :browser
    pipe_through :lifelist

    live_session :open_current_user,
      on_mount: [{KjogviWeb.UserAuth, :mount_current_user}] do
      live "/", Live.Lifelist.Index, :index
      live "/:year_or_location", Live.Lifelist.Index, :index
      live "/:year/:location", Live.Lifelist.Index, :index
    end
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

  ## Authentication routes

  scope "/", KjogviWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{KjogviWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/log_in", UserLoginLive, :new

      if Kjogvi.Config.allow_user_registration() do
        live "/users/register", UserRegistrationLive, :new
        live "/users/reset_password", UserForgotPasswordLive, :new
        live "/users/reset_password/:token", UserResetPasswordLive, :edit
      end
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", KjogviWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{KjogviWeb.UserAuth, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit

      if Kjogvi.Config.allow_user_registration() do
        live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
      end
    end
  end

  scope "/", KjogviWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    if Kjogvi.Config.allow_user_registration() do
      live_session :current_user,
        on_mount: [{KjogviWeb.UserAuth, :mount_current_user}] do
        live "/users/confirm/:token", UserConfirmationLive, :edit
        live "/users/confirm", UserConfirmationInstructionsLive, :new
      end
    end
  end
end
