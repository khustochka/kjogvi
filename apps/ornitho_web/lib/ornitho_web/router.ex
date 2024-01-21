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

          import Phoenix.Router, only: [get: 3, get: 4, post: 3, post: 4]
          import Phoenix.LiveView.Router, only: [live: 4, live_session: 3]

          live_session session_name, session_opts do
            # Assets
            get "/css-:md5", OrnithoWeb.Assets, :css, as: :ornitho_web_asset
            get "/js-:md5", OrnithoWeb.Assets, :js, as: :ornitho_web_asset

            get "/", OrnithoWeb.BooksController, :index, route_opts
            post "/books", OrnithoWeb.BooksController, :import, route_opts

            live "/:slug/:version", OrnithoWeb.Live.Book.Show, nil, route_opts
            live "/:slug/:version/page/:page", OrnithoWeb.Live.Book.Show, nil, route_opts
            live "/:slug/:version/:code", OrnithoWeb.Live.Taxa.Show, nil, route_opts
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
end
