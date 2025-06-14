defmodule KjogviWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use KjogviWeb, :controller
      use KjogviWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  def static_paths, do: ~w(
    assets
    fonts
    images
    android-chrome-192x192.png
    android-chrome-512x512.png
    apple-touch-icon.png
    favicon-16x16.png
    favicon-32x32.png
    favicon.ico
    robots.txt
    site.webmanifest
    )

  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: KjogviWeb.Layouts]

      import Plug.Conn
      use Gettext, backend: KjogviWeb.Gettext

      unquote(verified_routes())
      unquote(path_helpers())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {KjogviWeb.Layouts, :app}

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components and translation
      # CoreComponents preserved for reference but should be slowly phazed out
      # import KjogviWeb.CoreComponents
      import KjogviWeb.AccessComponents
      import KjogviWeb.BaseComponents
      import KjogviWeb.HeaderComponents
      import KjogviWeb.FlashComponents
      import KjogviWeb.FormComponents
      import KjogviWeb.IconComponents
      import KjogviWeb.MetaComponents
      import KjogviWeb.NavigationComponents
      import KjogviWeb.BirdingComponents
      import KjogviWeb.FormatComponents
      use Gettext, backend: KjogviWeb.Gettext

      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS
      alias KjogviWeb.CoreComponents

      # Routes generation with the ~p sigil
      unquote(verified_routes())
      unquote(path_helpers())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: KjogviWeb.Endpoint,
        router: KjogviWeb.Router,
        statics: KjogviWeb.static_paths()
    end
  end

  def path_helpers do
    quote do
      use KjogviWeb.Paths
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
