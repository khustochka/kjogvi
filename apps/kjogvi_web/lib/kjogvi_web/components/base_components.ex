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
