defmodule KjogviWeb.Live.Admin.Settings.Index do
  @moduledoc """
  Admin page for site-wide settings (`Kjogvi.Settings`). Currently covers the
  default taxonomy stamped on new users; other settings migrate here over time.

  The default taxonomy resolves database override → application config, so the
  page distinguishes the two: a saved selection writes an override row, and
  "Reset" removes it, returning the site to the config-derived value.
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Settings

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Site Settings")
     |> assign(:book_options, book_options())
     |> assign_taxonomy()}
  end

  @impl true
  def handle_event("save_taxonomy", %{"default_taxonomy" => ""}, socket) do
    {:noreply, put_flash(socket, :error, "Select a taxonomy first.")}
  end

  def handle_event("save_taxonomy", %{"default_taxonomy" => signature}, socket) do
    {:ok, _} = Settings.put_setting(:default_taxonomy, signature)

    {:noreply,
     socket
     |> put_flash(:info, "Default taxonomy saved.")
     |> assign_taxonomy()}
  end

  def handle_event("reset_taxonomy", _params, socket) do
    :ok = Settings.delete_setting(:default_taxonomy)

    {:noreply,
     socket
     |> put_flash(:info, "Default taxonomy reset to the configured value.")
     |> assign_taxonomy()}
  end

  defp assign_taxonomy(socket) do
    default_taxonomy = Settings.default_taxonomy()

    socket
    |> assign(:default_taxonomy, default_taxonomy)
    |> assign(:overridden, match?({:ok, _}, Settings.get_override(:default_taxonomy)))
    |> assign(:form, to_form(%{"default_taxonomy" => default_taxonomy}))
  end

  defp book_options do
    Ornitho.Finder.Book.all()
    |> Enum.map(fn b -> {"#{b.name} (#{b.slug}/#{b.version})", "#{b.slug}/#{b.version}"} end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.h1>Site Settings</.h1>

      <section id="default-taxonomy" class="border border-slate-300 rounded-lg p-6">
        <.h2 class="mb-4!">Default Taxonomy</.h2>

        <p class="text-sm text-slate-700 mb-2">
          New users are stamped with this taxonomy at registration. Changing it does not
          affect existing users — their observations stay on the taxonomy they registered with.
        </p>

        <p id="default-taxonomy-source" class="text-sm text-slate-700 mb-4">
          <%= cond do %>
            <% @overridden -> %>
              Set here, overriding the application config.
            <% @default_taxonomy -> %>
              Currently <strong>{@default_taxonomy}</strong>, from the application config;
              saving a selection overrides it.
            <% true -> %>
              No default taxonomy is configured; new users get none until one is selected.
          <% end %>
        </p>

        <.form id="default-taxonomy-form" for={@form} phx-submit="save_taxonomy">
          <CoreComponents.input
            field={@form[:default_taxonomy]}
            type="select"
            label="Default taxonomy"
            options={@book_options}
            prompt="Select taxonomy..."
          />

          <div class="mt-4 flex gap-2">
            <.button>Save</.button>
            <.button
              :if={@overridden}
              type="button"
              phx-click="reset_taxonomy"
              variant="danger"
              id="reset-taxonomy"
            >
              Reset to config value
            </.button>
          </div>
        </.form>
      </section>
    </div>
    """
  end
end
