defmodule KjogviWeb.BaseComponents do
  @moduledoc """
  The most basic UI components.

  This module is supposed to gradually replace CoreComponents.
  """
  alias KjogviWeb.IconComponents

  use Phoenix.Component

  import IconComponents

  alias Phoenix.LiveView.JS

  # use Gettext, backend: KjogviWeb.Gettext

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(KjogviWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(KjogviWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end

  @doc """
  Generates a generic error message.
  """
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="mt-3 flex gap-3 text-sm leading-6 text-rose-600">
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc ~S"""
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id"><%= user.id %></:col>
        <:col :let={user} label="username"><%= user.username %></:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="overflow-y-auto px-4 sm:overflow-visible sm:px-0">
      <table class="w-[40rem] mt-11 sm:w-full">
        <thead class="text-sm text-left leading-6 text-zinc-500">
          <tr>
            <th :for={col <- @col} class="p-0 pb-4 pr-6 font-normal">{col[:label]}</th>
            <th :if={@action != []} class="relative p-0 pb-4">
              <span class="sr-only">{Gettext.gettext(KjogviWeb.Gettext, "Actions")}</span>
            </th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={match?(%Phoenix.LiveView.LiveStream{}, @rows) && "stream"}
          class="relative divide-y divide-zinc-100 border-t border-zinc-200 text-sm leading-6 text-zinc-700"
        >
          <tr :for={row <- @rows} id={@row_id && @row_id.(row)} class="group hover:bg-zinc-50">
            <td
              :for={{col, i} <- Enum.with_index(@col)}
              phx-click={@row_click && @row_click.(row)}
              class={["relative p-0", @row_click && "hover:cursor-pointer"]}
            >
              <div class="block py-4 pr-6">
                <span class="absolute -inset-y-px right-0 -left-4 group-hover:bg-zinc-50 sm:rounded-l-xl" />
                <span class={["relative", i == 0 && "font-semibold text-zinc-900"]}>
                  {render_slot(col, @row_item.(row))}
                </span>
              </div>
            </td>
            <td :if={@action != []} class="relative w-14 p-0">
              <div class="relative whitespace-nowrap py-4 text-right text-sm font-medium">
                <span class="absolute -inset-y-px -right-4 left-0 group-hover:bg-zinc-50 sm:rounded-r-xl" />
                <span
                  :for={action <- @action}
                  class="relative ml-4 font-semibold leading-6 text-zinc-900 hover:text-zinc-700"
                >
                  {render_slot(action, @row_item.(row))}
                </span>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Shows an element with a transition.
  """
  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  @doc """
  Hides an element with a transition.
  """
  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  def link_to_top(assigns) do
    ~H"""
    <div aria-hidden="true" class="h-10"></div>
    <a
      id="link-to-top"
      phx-hook=".LinkToTop"
      href="#top"
      aria-label="Back to top"
      class="
        fixed bottom-6 left-6 z-40
        flex items-center justify-center
        size-11 rounded-full
        bg-white border border-stone-300 shadow-md
        text-stone-600 hover:text-stone-800 hover:bg-stone-50
        no-underline
        opacity-0 pointer-events-none translate-y-2
        transition-all duration-200
        data-[visible=true]:opacity-100 data-[visible=true]:pointer-events-auto data-[visible=true]:translate-y-0
      "
    >
      <.icon name="hero-arrow-up-solid w-5 h-5" />
      <script :type={Phoenix.LiveView.ColocatedHook} name=".LinkToTop">
        export default {
          mounted() {
            this.hideTimer = null
            this.atBottom = () => {
              const scrollBottom = window.scrollY + window.innerHeight
              return scrollBottom >= document.documentElement.scrollHeight - 50
            }
            this.onScroll = () => {
              if (window.scrollY <= 300) {
                clearTimeout(this.hideTimer)
                this.el.dataset.visible = "false"
                return
              }
              this.el.dataset.visible = "true"
              clearTimeout(this.hideTimer)
              if (!this.atBottom()) {
                this.hideTimer = setTimeout(() => {
                  if (!this.atBottom()) this.el.dataset.visible = "false"
                }, 1500)
              }
            }
            this.onHover = () => {
              clearTimeout(this.hideTimer)
              this.el.dataset.visible = "true"
            }
            window.addEventListener("scroll", this.onScroll, {passive: true})
            this.el.addEventListener("mouseenter", this.onHover)
            this.el.addEventListener("focus", this.onHover)
            this.el.addEventListener("mouseleave", this.onScroll)
            this.el.addEventListener("blur", this.onScroll)
          },
          destroyed() {
            clearTimeout(this.hideTimer)
            window.removeEventListener("scroll", this.onScroll)
          },
        }
      </script>
    </a>
    """
  end
end
