defmodule KjogviWeb.Router do
  use KjogviWeb, :router

  import KjogviWeb.UserAuth

  import OrnithoWeb.Router
  import Phoenix.LiveDashboard.Router
  import Oban.Web.Router

  import KjogviWeb.Plug

  pipeline :browser do
    plug :accepts, ["html"]
    plug :remove_trailing_slash
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {KjogviWeb.Layouts, :root}
    plug :put_layout, html: {KjogviWeb.Layouts, :public}
    plug :protect_from_forgery
    plug :put_secure_browser_headers

    plug :fetch_current_scope

    plug :require_setup
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  ## Setup administrator
  scope "/setup", KjogviWeb do
    pipe_through [:browser, :require_no_admin]

    get "/", SetupController, :enter
    post "/register", SetupController, :form
    post "/", SetupController, :create
  end

  # GLOBAL ROUTES

  scope "/", KjogviWeb do
    pipe_through [:browser]

    get "/", HomeController, :home
    get "/species/:slug", SpeciesController, :show
  end

  ## Authentication routes
  scope "/account", KjogviWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [
        {KjogviWeb.UserAuth, :redirect_if_user_is_authenticated}
      ] do
      live "/login", Live.Accounts.Login, :new

      live "/register", Live.Accounts.Registration, :new
      live "/reset-password", Live.Accounts.ForgotPassword, :new
      live "/reset-password/:token", Live.Accounts.ResetPassword, :edit
    end

    post "/register", Accounts.UserRegistrationController, :create
    post "/login", UserSessionController, :create
  end

  scope "/account", KjogviWeb do
    pipe_through [:browser]

    delete "/logout", UserSessionController, :delete

    live_session :current_user,
      on_mount: [
        {KjogviWeb.UserAuth, :mount_current_scope}
      ] do
      live "/confirm/:token", Live.Accounts.Confirmation, :edit
      live "/confirm", Live.Accounts.ConfirmationInstructions, :new
    end
  end

  # COMMUNITY ROUTES

  # Community area: aggregate public data across all users. The default
  # `:community` scope from the `:browser` pipeline drives it.
  scope "/community", KjogviWeb do
    pipe_through [:browser, :put_lifelist_status]

    live_session :community,
      on_mount: [
        {KjogviWeb.UserAuth, :mount_current_scope}
      ] do
      live "/lifelist", Live.Lifelist.Index, :index
      live "/lifelist/:year_or_location", Live.Lifelist.Index, :index
      live "/lifelist/:year/:location", Live.Lifelist.Index, :index
      live "/photos", Live.Photos.Index, :index
      live "/photos/page/:page", Live.Photos.Index, :index
    end
  end

  # PUBLIC USER ROUTES

  scope "/users/:username", KjogviWeb do
    pipe_through [:browser, :put_area_user, :put_lifelist_status]

    live_session :area_user,
      on_mount: [
        {KjogviWeb.UserAuth, :mount_area_user}
      ] do
      live "/", Live.Users.Show
      live "/lifelist", Live.Lifelist.Index, :index
      live "/lifelist/:year_or_location", Live.Lifelist.Index, :index
      live "/lifelist/:year/:location", Live.Lifelist.Index, :index
      live "/photos", Live.Photos.Index, :index
      live "/photos/page/:page", Live.Photos.Index, :index
    end
  end

  # AUTHENTICATED USER ROUTES

  scope "/my", KjogviWeb do
    pipe_through [:browser, :require_authenticated_user, :put_area_private]

    live_session :require_authenticated_user,
      layout: {KjogviWeb.Layouts, :private},
      on_mount: [
        {KjogviWeb.UserAuth, :ensure_authenticated},
        {KjogviWeb.UserAuth, :mount_area_private}
      ] do
      live "/locations", Live.My.Locations.Index, :index
      live "/locations/new", Live.Locations.Form, :new
      live "/locations/:slug/edit", Live.Locations.Form, :edit
      live "/locations/:slug/members", Live.My.Locations.Members, :edit
      live "/locations/:slug", Live.My.Locations.Show, :show

      live "/checklists", Live.My.Checklists.Index, :index
      live "/checklists/page/:page", Live.My.Checklists.Index, :index
      live "/checklists/new", Live.My.Checklists.Form, :new
      live "/checklists/:id/edit", Live.My.Checklists.Form, :edit
      live "/checklists/:id", Live.My.Checklists.Show, :show

      live "/images", Live.My.Images.Index, :index
      live "/images/page/:page", Live.My.Images.Index, :index
      live "/images/new", Live.My.Images.Form, :new
      live "/images/:id/edit", Live.My.Images.Form, :edit
      live "/images/:id", Live.My.Images.Show, :show

      live "/logbook", Live.My.Logbook.Index, :index

      live "/settings", Live.My.Settings.Profile, :redirect
      live "/settings/profile", Live.My.Settings.Profile, :edit
      live "/settings/security", Live.My.Settings.Security, :edit
      live "/settings/security/confirm_email/:token", Live.My.Settings.Security, :confirm_email
      live "/settings/preferences", Live.My.Settings.Preferences, :edit

      live "/lifelist", Live.Lifelist.Index, :index
      live "/lifelist/:year_or_location", Live.Lifelist.Index, :index
      live "/lifelist/:year/:location", Live.Lifelist.Index, :index

      live "/imports", Live.My.Imports.Index, :index
    end
  end

  # ADMIN ROUTES

  scope "/admin", KjogviWeb do
    pipe_through [:browser, :require_admin, :put_area_admin]

    live_session :admin_paths,
      layout: {KjogviWeb.Layouts, :private},
      on_mount: [
        {KjogviWeb.UserAuth, :ensure_admin},
        {KjogviWeb.UserAuth, :mount_area_admin}
      ] do
      live "/locations", Live.Admin.Locations.Index, :index
      live "/locations/new", Live.Locations.Form, :new
      live "/locations/:slug/edit", Live.Locations.Form, :edit
      live "/locations/:slug", Live.Admin.Locations.Show, :show

      live "/ebird/locations", Live.Admin.Ebird.Locations.Index, :index
      live "/ebird/locations/:country_code", Live.Admin.Ebird.Locations.Show, :show

      live "/imports", Live.Admin.Imports.Index, :index
      live "/imports/locations", Live.Admin.Imports.Locations.Index, :index

      live "/import_logs", Live.Admin.ImportLogs.Index, :index
      live "/import_logs/page/:page", Live.Admin.ImportLogs.Index, :index
      live "/import_logs/:id", Live.Admin.ImportLogs.Show, :show

      live "/users", Live.Admin.Users.Index, :index
      live "/users/page/:page", Live.Admin.Users.Index, :index
      live "/users/:id/settings", Live.Admin.Users.Settings, :edit

      live "/settings", Live.Admin.Settings.Index, :index
    end

    get "/import_logs/:id/upload", Admin.ImportUploadController, :download

    ornitho_web "/taxonomy",
      root_layout: {KjogviWeb.Layouts, :root},
      app_layout: {KjogviWeb.Layouts, :private},
      on_mount: [
        {KjogviWeb.UserAuth, :ensure_admin},
        {KjogviWeb.UserAuth, :mount_area_admin}
      ]

    oban_dashboard "/oban",
      on_mount: [
        {KjogviWeb.UserAuth, :ensure_admin},
        {KjogviWeb.UserAuth, :mount_area_admin}
      ]

    live_dashboard "/dashboard",
      metrics: KjogviWeb.Telemetry,
      env_keys: [
        "ECTO_IPV6",
        "PHX_HOST",
        "PHX_PORT",
        "DNS_CLUSTER_QUERY",
        "GIT_REVISION",
        "RELEASE_ENV",
        "RELEASE_VERSION"
      ],
      on_mount: [
        {KjogviWeb.UserAuth, :ensure_admin},
        {KjogviWeb.UserAuth, :mount_area_admin}
      ]
  end

  # Other scopes may use custom stacks.
  # scope "/api", KjogviWeb do
  #   pipe_through :api
  # end

  # DEV ROUTES

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:kjogvi_web, :dev_routes) do
    scope "/dev" do
      pipe_through [:browser, :require_admin]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
