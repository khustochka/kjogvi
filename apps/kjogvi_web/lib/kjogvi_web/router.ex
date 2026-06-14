defmodule KjogviWeb.Router do
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
    plug :put_layout, html: {KjogviWeb.Layouts, :public}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    
    plug :fetch_current_scope
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # TODO: check for admin presence
  scope "/setup", KjogviWeb do
    pipe_through [:browser]

    get "/", SetupController, :enter
    post "/register", SetupController, :form
    post "/", SetupController, :create
  end

  scope "/", KjogviWeb do
    pipe_through [:browser]

    get "/", HomeController, :home
    get "/species/:slug", SpeciesController, :show
  end

  ## Authentication routes
  # TODO: change to /account? or just plain /login etc.

  scope "/", KjogviWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [
        {KjogviWeb.UserAuth, :redirect_if_user_is_authenticated}
      ] do
      live "/users/log_in", UserLoginLive, :new

      live "/users/register", UserRegistrationLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", KjogviWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [
        {KjogviWeb.UserAuth, :mount_current_scope}
      ] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end

  # PUBLIC USER ROUTES

  scope "/users/:username", KjogviWeb do
    pipe_through [:browser, :put_section_user]

    live_session :section_user,
      on_mount: [
        {KjogviWeb.UserAuth, :mount_section_user}
      ] do
      live "/", Live.Users.Show
      live "/lifelist", Live.Lifelist.Index
      live "/photos", Live.Photos.Index, :index
      live "/photos/page/:page", Live.Photos.Index, :index
    end
  end

  # AUTHENTICATED USER ROUTES

  scope "/my", KjogviWeb do
    pipe_through [:browser, :require_authenticated_user, :put_section_private]

    live_session :require_authenticated_user,
      layout: {KjogviWeb.Layouts, :private},
      on_mount: [
        {KjogviWeb.UserAuth, :ensure_authenticated},
        {KjogviWeb.UserAuth, :mount_section_private}
      ] do
      live "/locations", Live.My.Locations.Index, :index
      live "/locations/countries", Live.My.Countries.Index, :index
      live "/locations/new", Live.My.Locations.Form, :new
      live "/locations/:slug/edit", Live.My.Locations.Form, :edit
      live "/locations/:slug", Live.My.Locations.Show, :show

      live "/cards", Live.My.Cards.Index, :index
      live "/cards/page/:page", Live.My.Cards.Index, :index
      live "/cards/new", Live.My.Cards.Form, :new
      live "/cards/:id/edit", Live.My.Cards.Form, :edit
      live "/cards/:id", Live.My.Cards.Show, :show

      live "/images", Live.My.Images.Index, :index
      live "/images/page/:page", Live.My.Images.Index, :index
      live "/images/new", Live.My.Images.Form, :new
      live "/images/:id/edit", Live.My.Images.Form, :edit
      live "/images/:id", Live.My.Images.Show, :show

      live "/logbook", Live.My.Logbook.Index, :index

      live "/account/settings", Live.My.Account.Settings, :edit
      live "/account/settings/confirm_email/:token", Live.My.Account.Settings, :confirm_email

      live "/lifelist", Live.Lifelist.Index, :index
      live "/lifelist/:year_or_location", Live.Lifelist.Index, :index
      live "/lifelist/:year/:location", Live.Lifelist.Index, :index

      live "/imports", Live.My.Imports.Index, :index
    end
  end

  # ADMIN ROUTES

  scope "/admin", KjogviWeb do
    pipe_through [:browser, :require_admin, :put_section_admin]

    live_session :admin_paths,
      layout: {KjogviWeb.Layouts, :private},
      on_mount: [
        {KjogviWeb.UserAuth, :ensure_admin},
        {KjogviWeb.UserAuth, :mount_section_admin}
      ] do
      live "/exclusive-tasks", Live.Admin.ExclusiveTasks.Index, :index
    end

    ornitho_web "/taxonomy",
      root_layout: {KjogviWeb.Layouts, :root},
      app_layout: {KjogviWeb.Layouts, :private},
      on_mount: [
        {KjogviWeb.UserAuth, :ensure_admin},
        {KjogviWeb.UserAuth, :mount_section_admin}
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
        {KjogviWeb.UserAuth, :mount_section_admin}
      ]
  end

  # PUBLIC ROUTES

  # scope "/lifelist", KjogviWeb do
  #   pipe_through [:browser]

  #   live_session :open_current_user,
  #     on_mount: [
  #       {KjogviWeb.UserAuth, :mount_current_scope}
  #     ] do
  #     live "/", Live.Lifelist.Index, :public_view
  #     live "/:year_or_location", Live.Lifelist.Index, :public_view
  #     live "/:year/:location", Live.Lifelist.Index, :public_view
  #   end
  # end

  # scope "/photos", KjogviWeb do
  #   pipe_through [:browser]

  #   live_session :public_photos,
  #     on_mount: [
  #       {KjogviWeb.UserAuth, :mount_current_scope}
  #     ] do
  #     live "/", Live.Photos.Index, :index
  #     live "/page/:page", Live.Photos.Index, :index
  #   end
  # end

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
