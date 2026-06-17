defmodule KjogviWeb.AccountSettingsComponents do
  @moduledoc """
  Layout and navigation for the account settings sections
  (Profile / Security / Preferences).
  """
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: KjogviWeb.Endpoint,
    router: KjogviWeb.Router

  @sections [
    {:profile, "Profile", "/my/settings/profile"},
    {:security, "Email and password", "/my/settings/security"},
    {:preferences, "Preferences", "/my/settings/preferences"}
  ]

  @doc """
  Renders the account settings layout: a selection panel that sits on the left
  on desktop and stacks above the content on small screens, plus the section
  content passed as the default slot.

  Pass `active` as one of `:profile`, `:security`, `:preferences` to highlight
  the current section.

  ## Examples

      <.account_settings active={:profile}>
        ...section forms...
      </.account_settings>
  """
  attr :active, :atom, required: true, values: [:profile, :security, :preferences]
  slot :inner_block, required: true

  def account_settings(assigns) do
    assigns = assign(assigns, :sections, @sections)

    ~H"""
    <div class="flex flex-col md:flex-row md:gap-8">
      <nav aria-label="Account settings" class="md:w-48 md:shrink-0 mb-6 md:mb-0">
        <ul class="flex flex-col divide-y divide-zinc-200 border-y border-zinc-200">
          <li :for={{key, label, path} <- @sections}>
            <.link
              navigate={path}
              aria-current={if(key == @active, do: "page")}
              class={[
                "block px-3 py-2 text-sm font-normal font-header no-underline",
                if(key == @active,
                  do: "bg-zinc-100 text-zinc-900",
                  else: "text-zinc-600 hover:bg-zinc-50 hover:text-zinc-900"
                )
              ]}
            >
              {label}
            </.link>
          </li>
        </ul>
      </nav>

      <div class="flex-1 min-w-0">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end
end
