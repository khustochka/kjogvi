defmodule OrnithoWeb.Router do
  defmacro ornitho_web(path, opts \\ []) do
    opts =
      if Macro.quoted_literal?(opts) do
        Macro.prewalk(opts, &expand_alias(&1, __CALLER__))
      else
        opts
      end

    scope =
      quote bind_quoted: binding() do
        scope path, alias: false, as: false do
          {session_name, session_opts, route_opts} =
            OrnithoWeb.Router.__options__(opts)

          import Phoenix.Router, only: [get: 3, get: 4]
          import Phoenix.LiveView.Router, only: [live: 4, live_session: 3]

          live_session session_name, session_opts do
            # Assets
            get "/css-:md5", OrnithoWeb.Assets, :css, as: :ornitho_web_asset
            get "/js-:md5", OrnithoWeb.Assets, :js, as: :ornitho_web_asset

            get "/", OrnithoWeb.BooksController, :index, route_opts

            live "/:slug/:version", OrnithoWeb.BookLive.Show, nil, route_opts
            live "/:slug/:version/page/:page", OrnithoWeb.BookLive.Show, nil, route_opts
            live "/:slug/:version/:code", OrnithoWeb.TaxaLive.Show, nil, route_opts
            #   # LiveDashboard assets
            #   get "/css-:md5", Phoenix.LiveDashboard.Assets, :css, as: :live_dashboard_asset
            #   get "/js-:md5", Phoenix.LiveDashboard.Assets, :js, as: :live_dashboard_asset

            #   # All helpers are public contracts and cannot be changed
            #   live "/", Phoenix.LiveDashboard.PageLive, :home, route_opts
            #   live "/:page", Phoenix.LiveDashboard.PageLive, :page, route_opts
            #   live "/:node/:page", Phoenix.LiveDashboard.PageLive, :page, route_opts
          end
        end
      end

    # TODO: Remove check once we require Phoenix v1.7
    if Code.ensure_loaded?(Phoenix.VerifiedRoutes) do
      quote do
        unquote(scope)

        unless Module.get_attribute(__MODULE__, :ornitho_web_prefix) do
          @ornitho_web_prefix Phoenix.Router.scoped_path(__MODULE__, path)
          def __ornitho_web_prefix__, do: @ornitho_web_prefix
        end
      end
    else
      scope
    end
  end

  defp expand_alias({:__aliases__, _, _} = alias, env),
    do: Macro.expand(alias, %{env | function: {:ornitho_web, 2}})

  defp expand_alias(other, _env), do: other

  @doc false
  def __options__(options) do
    live_socket_path = Keyword.get(options, :live_socket_path, "/live")

    csp_nonce_assign_key =
      case options[:csp_nonce_assign_key] do
        nil -> nil
        key when is_atom(key) -> %{img: key, style: key, script: key}
        %{} = keys -> Map.take(keys, [:img, :style, :script])
      end

    session_args = [
      csp_nonce_assign_key
    ]

    {
      options[:live_session_name] || :ornitho_web,
      [
        session: {__MODULE__, :__session__, session_args},
        root_layout: {OrnithoWeb.Layouts, :root},
        on_mount: options[:on_mount] || nil
      ],
      [
        private: %{live_socket_path: live_socket_path, csp_nonce_assign_key: csp_nonce_assign_key},
        as: :ornitho_web
      ]
    }
  end

  @doc false
  def __session__(
        conn,
        csp_nonce_assign_key
      ) do

    %{
      "csp_nonces" => %{
        img: conn.assigns[csp_nonce_assign_key[:img]],
        style: conn.assigns[csp_nonce_assign_key[:style]],
        script: conn.assigns[csp_nonce_assign_key[:script]]
      }
    }
  end

  #   use OrnithoWeb, :router

  #   pipeline :browser do
  #     plug :accepts, ["html"]
  #     plug :fetch_session
  #     plug :fetch_live_flash
  #     plug :put_root_layout, html: {OrnithoWeb.Layouts, :root}
  #     plug :protect_from_forgery
  #     plug :put_secure_browser_headers,
  #       %{"content-security-policy-report-only" =>
  #       "default-src 'self' https:; img-src 'self' https: data:; font-src 'self' https: data:"}
  #   end

  #   pipeline :api do
  #     plug :accepts, ["json"]
  #   end

  #   scope "/", OrnithoWeb do
  #     pipe_through :browser

  #     get "/", PageController, :home
  #   end

  #   scope "/taxonomy", OrnithoWeb do
  #     pipe_through :browser

  #     get "/", BooksController, :index
  #     live "/:slug/:version", BookLive.Show
  #     live "/:slug/:version/page/:page", BookLive.Show
  #     live "/:slug/:version/:code", TaxaLive.Show
  #   end

  #   # Other scopes may use custom stacks.
  #   # scope "/api", OrnithoWeb do
  #   #   pipe_through :api
  #   # end

  #   # Enable LiveDashboard and Swoosh mailbox preview in development
  #   if Application.compile_env(:ornitho_web, :dev_routes) do
  #     # If you want to use the LiveDashboard in production, you should put
  #     # it behind authentication and allow only admins to access it.
  #     # If your application does not have an admins-only section yet,
  #     # you can use Plug.BasicAuth to set up some basic authentication
  #     # as long as you are also using SSL (which you should anyway).
  #     import Phoenix.LiveDashboard.Router

  #     scope "/dev" do
  #       pipe_through :browser

  #       live_dashboard "/dashboard", metrics: OrnithoWeb.Telemetry
  #     end
  #   end
end
