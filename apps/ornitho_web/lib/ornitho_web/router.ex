defmodule OrnithoWeb.Router do
  use OrnithoWeb, :router

  scope "/", OrnithoWeb do
    get "/", BooksController, :index
    post "/import", BooksController, :import

    live "/:slug/:version", Live.Book.Show, nil
    live "/:slug/:version/page/:page", Live.Book.Show, nil
    live "/:slug/:version/:code", Live.Taxa.Show, nil
  end
end

# defmodule OrnithoWeb.Router do
#   defmacro ornitho_web(path, opts \\ []) do
#     opts =
#       if Macro.quoted_literal?(opts) do
#         Macro.prewalk(opts, &expand_alias(&1, __CALLER__))
#       else
#         opts
#       end

#     scope =
#       quote bind_quoted: [path: path, opts: opts], generated: true do
#         {session_name, session_opts, route_opts} =
#           OrnithoWeb.Router.__options__(opts)

#         pipeline :ornitho_web_pipeline do
#           plug :put_root_layout, session_opts[:root_layout]
#           plug :put_layout, session_opts[:layout]
#         end

#         scope path, alias: false, as: false do
#           import Plug.Conn
#           import Phoenix.Controller
#           import Phoenix.LiveView.Router

#           pipe_through :ornitho_web_pipeline

#           live_session session_name, session_opts do
#             # Assets
#             get "/css-:md5", OrnithoWeb.Assets, :css, as: :ornitho_web_asset
#             get "/js-:md5", OrnithoWeb.Assets, :js, as: :ornitho_web_asset

#             get "/", OrnithoWeb.BooksController, :index, route_opts
#             post "/import", OrnithoWeb.BooksController, :import, route_opts

#             live "/:slug/:version", OrnithoWeb.Live.Book.Show, nil, route_opts
#             live "/:slug/:version/page/:page", OrnithoWeb.Live.Book.Show, nil, route_opts
#             live "/:slug/:version/:code", OrnithoWeb.Live.Taxa.Show, nil, route_opts
#           end
#         end
#       end

#     # TODO: Remove check once we require Phoenix v1.7
#     if Code.ensure_loaded?(Phoenix.VerifiedRoutes) do
#       quote do
#         unquote(scope)

#         unless Module.get_attribute(__MODULE__, :ornitho_web_prefix) do
#           @ornitho_web_prefix Phoenix.Router.scoped_path(__MODULE__, path)
#           def __ornitho_web_prefix__, do: @ornitho_web_prefix
#         end
#       end
#     else
#       scope
#     end
#   end

#   defp expand_alias({:__aliases__, _, _} = alias, env),
#     do: Macro.expand(alias, %{env | function: {:ornitho_web, 2}})

#   defp expand_alias(other, _env), do: other

#   @doc false
#   def __options__(options) do
#     live_socket_path = Keyword.get(options, :live_socket_path, "/live")

#     csp_nonce_assign_key = __extract_csp_nonce_assign_key(options)

#     root_layout =
#       case options[:root_layout] do
#         nil -> {OrnithoWeb.Layouts, :root}
#         layout -> layout
#       end

#     app_layout =
#       case options[:app_layout] do
#         nil -> {OrnithoWeb.Layouts, :app}
#         layout -> layout
#       end

#     session_args = [
#       csp_nonce_assign_key
#     ]

#     {
#       options[:live_session_name] || :ornitho_web,
#       [
#         session: {__MODULE__, :__session__, session_args},
#         root_layout: root_layout,
#         layout: app_layout,
#         on_mount: options[:on_mount] || nil
#       ],
#       [
#         private: %{live_socket_path: live_socket_path, csp_nonce_assign_key: csp_nonce_assign_key},
#         as: :ornitho_web
#       ]
#     }
#   end

#   defp __extract_csp_nonce_assign_key(options) do
#     case options[:csp_nonce_assign_key] do
#       nil -> nil
#       key when is_atom(key) -> %{img: key, style: key, script: key}
#       %{} = keys -> Map.take(keys, [:img, :style, :script])
#     end
#   end

#   @doc false
#   def __session__(
#         conn,
#         csp_nonce_assign_key
#       ) do
#     %{
#       "csp_nonces" => %{
#         img: conn.assigns[csp_nonce_assign_key[:img]],
#         style: conn.assigns[csp_nonce_assign_key[:style]],
#         script: conn.assigns[csp_nonce_assign_key[:script]]
#       }
#     }
#   end
# end
