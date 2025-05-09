defmodule KjogviWeb.FlashComponents do
  @moduledoc """
  Components to render flash messages.
  """
  use Phoenix.Component

  import KjogviWeb.CoreComponents
  use Gettext, backend: KjogviWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.main_flash flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def main_flash(assigns) do
    ~H"""
    <div id={@id}>
      <.flash_default kind={:info} id={"#{@id}-info"} title={gettext("Success!")} flash={@flash} />
      <.flash_default kind={:error} id={"#{@id}-error"} title={gettext("Error!")} flash={@flash} />
    </div>
    """
  end

  attr :id, :string, default: "hidden-flash", doc: "the optional id of flash container"

  @doc """
  Shows hidden flash group with standard titles and content.

  ## Examples

      <.hidden_flash />
  """
  def hidden_flash(assigns) do
    ~H"""
    <div id={@id}>
      <.flash_popup
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error")}
        phx-connected={hide("#client-error")}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
      </.flash_popup>

      <.flash_popup
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error")}
        phx-connected={hide("#server-error")}
        hidden
      >
        {gettext("Hang in there while we get back on track")}
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
      </.flash_popup>
    </div>
    """
  end

  @doc """
  Renders popup flash notices.

  ## Examples

      <.flash_popup kind={:info} flash={@flash} />
      <.flash_popup kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash_popup>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash_popup(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class={[
        "fixed top-2 right-2 mr-2 w-80 sm:w-96 z-50 rounded-lg p-3 ring-1",
        @kind == :info && "bg-emerald-50 text-emerald-800 ring-emerald-500 fill-cyan-900",
        @kind == :error && "bg-rose-50 text-rose-900 shadow-md ring-rose-500 fill-rose-900"
      ]}
      {@rest}
    >
      <p :if={@title} class="flex items-center gap-1.5 text-sm font-semibold leading-6">
        <.icon :if={@kind == :info} name="hero-information-circle-mini" class="h-4 w-4" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle-mini" class="h-4 w-4" />
        {@title}
      </p>
      <p class="mt-2 text-sm leading-5">{msg}</p>

      <button type="button" class="group absolute top-1 right-1 p-2" aria-label={gettext("close")}>
        <.icon name="hero-x-mark-solid" class="h-5 w-5 opacity-40 group-hover:opacity-70" />
      </button>
    </div>
    """
  end

  @doc """
  Renders default flash notices.

  ## Examples

      <.flash_default kind={:info} flash={@flash} />
      <.flash_default kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash_default>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash_default(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={# JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class={[
        "flex justify-between gap-2 mr-2 mb-2 z-50 p-3",
        @kind == :info && "bg-emerald-50 text-emerald-800 ring-emerald-500 fill-cyan-900",
        @kind == :error && "bg-rose-50 text-rose-900 shadow-md ring-rose-500 fill-rose-900"
      ]}
      {@rest}
    >
      <div class="flex gap-2 items-center">
        <div :if={@title} class="flex items-center gap-1.5 text-sm font-semibold leading-6">
          <.icon :if={@kind == :info} name="hero-information-circle-mini" class="h-4 w-4" />
          <.icon :if={@kind == :error} name="hero-exclamation-circle-mini" class="h-4 w-4" />
        </div>
        <p class="text-sm leading-5">{msg}</p>
      </div>
      <%!-- <button type="button" class="group p-2" aria-label={gettext("close")}>
        <.icon name="hero-x-mark-solid" class="h-5 w-5 opacity-40 group-hover:opacity-70" />
      </button> --%>
    </div>
    """
  end
end
