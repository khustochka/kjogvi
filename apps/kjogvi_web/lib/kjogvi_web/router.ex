defmodule KjogviWeb.Router do
  require Kjogvi.Config

  use KjogviWeb, :router

  import KjogviWeb.UserAuth

  import OrnithoWeb.Router
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

  pipeline :user_fetching do
    Kjogvi.Config.with_single_user do
      plug :fetch_main_user
    end

    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  Kjogvi.Config.with_single_user do
    scope "/setup", KjogviWeb do
      pipe_through [:browser]

      get "/", SetupController, :enter
      post "/", SetupController, :new
      post "/save", SetupController, :create
    end
  end

  scope "/", KjogviWeb do
    pipe_through [:browser, :user_fetching]

    get "/", HomeController, :home
  end

  # AUTHENTICATED USER ROUTES

  scope "/my", KjogviWeb.Live do
    pipe_through [:browser, :user_fetching, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [
        {KjogviWeb.UserAuth, :ensure_authenticated},
        {KjogviWeb.UserAuth, :mount_main_user}
      ] do
      live "/locations", My.Locations.Index, :index
      live "/locations/countries", My.Countries.Index, :index

      live "/cards", My.Cards.Index, :index
      live "/cards/page/:page", My.Cards.Index, :index
      live "/cards/:id", My.Cards.Show, :show

      live "/account/settings", My.Account.Settings, :edit
      live "/account/settings/confirm_email/:token", My.Account.Settings, :confirm_email
    end
  end

  # ADMIN ROUTES

  scope "/", KjogviWeb do
    pipe_through [:browser, :user_fetching, :require_admin]

    live_session :admin_paths,
      on_mount: [{KjogviWeb.UserAuth, :ensure_admin}, {KjogviWeb.UserAuth, :mount_main_user}] do
      live "/admin/tasks", Live.Admin.Tasks.Index, :index
      post "/admin/tasks/legacy_import", Admin.TasksController, :legacy_import
    end

    ornitho_web "/taxonomy",
      root_layout: {KjogviWeb.Layouts, :root},
      app_layout: {KjogviWeb.Layouts, :app},
      on_mount: [{KjogviWeb.UserAuth, :ensure_admin}, {KjogviWeb.UserAuth, :mount_main_user}]

    live_dashboard "/dashboard",
      metrics: KjogviWeb.Telemetry,
      env_keys: ["ECTO_IPV6", "PHX_HOST", "PHX_PORT", "DNS_CLUSTER_QUERY"],
      on_mount: [{KjogviWeb.UserAuth, :ensure_admin}, {KjogviWeb.UserAuth, :mount_main_user}]
  end

  # PUBLIC ROUTES

  scope "/lifelist", KjogviWeb do
    pipe_through [:browser, :user_fetching]

    live_session :open_current_user,
      on_mount: [
        {KjogviWeb.UserAuth, :mount_current_user},
        {KjogviWeb.UserAuth, :mount_main_user}
      ] do
      live "/", Live.Lifelist.Index, :index
      live "/:year_or_location", Live.Lifelist.Index, :index
      live "/:year/:location", Live.Lifelist.Index, :index
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", KjogviWeb do
  #   pipe_through :api
  # end

  ## Authentication routes

  scope "/", KjogviWeb do
    pipe_through [:browser, :user_fetching, :redirect_if_user_is_authenticated]

    registration_on_mount = [{KjogviWeb.UserAuth, :redirect_if_user_is_authenticated}]

    Kjogvi.Config.with_single_user do
      registration_on_mount = registration_on_mount ++ [{KjogviWeb.UserAuth, :mount_main_user}]
    end

    live_session :redirect_if_user_is_authenticated,
      on_mount: registration_on_mount do
      live "/users/log_in", UserLoginLive, :new

      Kjogvi.Config.with_multiuser do
        live "/users/register", UserRegistrationLive, :new
        live "/users/reset_password", UserForgotPasswordLive, :new
        live "/users/reset_password/:token", UserResetPasswordLive, :edit
      end
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", KjogviWeb do
    pipe_through [:browser, :user_fetching]

    delete "/users/log_out", UserSessionController, :delete

    Kjogvi.Config.with_multiuser do
      live_session :current_user,
        on_mount: [{KjogviWeb.UserAuth, :mount_current_user}] do
        live "/users/confirm/:token", UserConfirmationLive, :edit
        live "/users/confirm", UserConfirmationInstructionsLive, :new
      end
    end
  end

  # DEV ROUTES

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:kjogvi_web, :dev_routes) do
    scope "/dev" do
      pipe_through [:browser, :user_fetching, :require_admin]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
