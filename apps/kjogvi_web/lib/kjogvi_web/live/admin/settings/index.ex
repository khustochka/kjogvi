defmodule KjogviWeb.Live.Admin.Settings.Index do
  @moduledoc """
  Admin page for site-wide settings (`Kjogvi.Settings`): the default taxonomy
  stamped on new users, and the access kill switches for registration, password
  reset, and confirmation.

  Every setting resolves database override → application config; the taxonomy
  can be reset back to the config value, while a flag stays on whatever it was
  last toggled to.

  Settings are stored negatively (`registration_disabled`) but presented
  positively: the page states whether the *feature* is enabled and labels the
  button with the action it performs, so the reader never inverts a flag name.
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Settings

  # Each flag is stored as `<feature>_disabled`, but the UI speaks about the
  # feature, never the switch: `feature` names it, and status/action are always
  # phrased as what the feature is and what the click does to it.
  @flags [
    registration_disabled: %{
      feature: "Registration",
      description: "New user sign-up. Existing users can always log in.",
      reader: &Settings.registration_disabled?/0
    },
    forgot_reset_password_disabled: %{
      feature: "Password reset",
      description: "The forgot/reset password flow.",
      reader: &Settings.forgot_reset_password_disabled?/0
    },
    confirmation_disabled: %{
      feature: "Confirmation",
      description: "The email/account confirmation flow.",
      reader: &Settings.confirmation_disabled?/0
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Site Settings")
     |> assign(:book_options, book_options())
     |> assign_taxonomy()
     |> assign_flags()}
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

  # `disabled` is the value to store, not the current state: the button sends
  # what the click should make true.
  def handle_event("save_flag", %{"key" => key, "disabled" => disabled}, socket) do
    flag = flag_key!(key)
    disabled = disabled == "true"
    {:ok, _} = Settings.put_setting(flag, disabled)

    feature = @flags[flag].feature
    verb = if disabled, do: "disabled", else: "enabled"

    {:noreply,
     socket
     |> put_flash(:info, "#{feature} #{verb}.")
     |> assign_flags()}
  end

  # Only known flag names may reach put_setting/2 — the key comes from the client.
  defp flag_key!(key) do
    Enum.find(Keyword.keys(@flags), &(to_string(&1) == key)) ||
      raise ArgumentError, "unknown setting #{inspect(key)}"
  end

  defp assign_flags(socket) do
    flags =
      Enum.map(@flags, fn {key, meta} ->
        Map.merge(meta, %{key: key, enabled: not meta.reader.()})
      end)

    assign(socket, :flags, flags)
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

      <section id="access-flags" class="border border-slate-300 rounded-lg p-6">
        <.h2 class="mb-4!">Access</.h2>

        <p class="text-sm text-slate-700 mb-4">
          Kill switches for the public account flows.
        </p>

        <ul class="divide-y divide-slate-200">
          <li :for={flag <- @flags} id={"flag-#{flag.key}"} class="py-4 first:pt-0 last:pb-0">
            <div class="flex items-center justify-between gap-4">
              <div>
                <.h3
                  id={"flag-#{flag.key}-state"}
                  class={[
                    "mb-1!",
                    if(flag.enabled, do: "text-emerald-700!", else: "text-rose-700!")
                  ]}
                >
                  {flag.feature} {if flag.enabled, do: "enabled", else: "disabled"}
                </.h3>
                <p class="text-sm text-slate-700">{flag.description}</p>
              </div>

              <.button
                id={"toggle-#{flag.key}"}
                phx-click="save_flag"
                phx-value-key={flag.key}
                phx-value-disabled={to_string(flag.enabled)}
                variant={if flag.enabled, do: "danger", else: "primary"}
                class="shrink-0"
              >
                {if flag.enabled, do: "Disable", else: "Enable"} {String.downcase(flag.feature)}
              </.button>
            </div>
          </li>
        </ul>
      </section>
    </div>
    """
  end
end
