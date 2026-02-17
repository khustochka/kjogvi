defmodule KjogviWeb.FormComponents do
  @moduledoc """
  Components for building forms.
  """

  use Phoenix.Component

  alias KjogviWeb.IconComponents
  alias KjogviWeb.CoreComponents
  alias Phoenix.LiveView.JS
  use Gettext, backend: KjogviWeb.Gettext

  import IconComponents

  @doc """
  Only implemented for password so far
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :string, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :string, default: nil, doc: "the input error class to use over defaults"
  attr :password_toggle, :boolean, default: true, doc: "whether to toggle password visibility"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &CoreComponents.translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "password"} = assigns) do
    ~H"""
    <fieldset class="fieldset mb-2">
      <label for={@id}>
        <span :if={@label} class="block text-sm font-semibold leading-6 text-zinc-800">{@label}</span>
        <div class="relative">
          <input
            type={@type}
            name={@name}
            id={@id}
            value={Phoenix.HTML.Form.normalize_value(@type, @value)}
            class={[
              "mt-2 block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6",
              @password_toggle && "pe-10",
              @errors == [] && "border-zinc-300 focus:border-zinc-400",
              @errors != [] && "border-rose-400 focus:border-rose-400",
              @class
            ]}
            {@rest}
          />
          <span
            :if={@password_toggle}
            phx-click={
              JS.toggle_attribute({:type, :password, :text}, to: "input##{@id}")
              |> JS.toggle(to: {:inner, "span.hero-eye"})
              |> JS.toggle(to: {:inner, "span.hero-eye-slash"})
            }
            class="hover:cursor-pointer text-zinc-400 absolute pe-3 end-0 inset-y-2 pt-[3px]"
          >
            <.icon name="hero-eye" class="w-5 h-5 block" />
            <.icon name="hero-eye-slash" class="w-5 h-5 block hidden" />
            <span class="sr-only">Show/hide password</span>
          </span>
        </div>
      </label>
      <CoreComponents.error :for={msg <- @errors}>{msg}</CoreComponents.error>
    </fieldset>
    """
  end
end
