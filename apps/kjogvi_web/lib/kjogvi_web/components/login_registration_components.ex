defmodule KjogviWeb.LoginRegistrationComponents do
  @moduledoc """
  Components for login and registration pages. They are unique, so it is easier to define them
  separately, than customize shared components.
  """

  use Phoenix.Component

  alias KjogviWeb.FormComponents

  attr :header_class, :any, default: nil

  slot :inner_block, required: true
  slot :subheader

  def header(assigns) do
    ~H"""
    <div class="mb-6 text-center font-header font-normal">
      <h1 class={@header_class || "sm:mb-4 mb-2 lg:text-5xl sm:text-4xl text-2xl"}>
        {render_slot(@inner_block)}
      </h1>
      <div :if={@subheader != []} class="mt-2 md:text-xl test-base text-zinc-400">
        {render_slot(@subheader)}
      </div>
    </div>
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, default: nil
  attr :show_required, :boolean, default: false
  attr :rest, :global, include: ~w(autocomplete phx-blur phx-debounce required spellcheck)

  def email_input(assigns) do
    ~H"""
    <fieldset class="fieldset">
      <.field_label :if={@label} for={@field.id} show_required={@show_required}>
        {@label}
      </.field_label>
      <input
        type="email"
        name={@field.name}
        id={@field.id}
        value={Phoenix.HTML.Form.normalize_value("email", @field.value)}
        class={input_class(@field)}
        {@rest}
      />
      <.field_errors field={@field} />
    </fieldset>
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, default: nil
  attr :show_required, :boolean, default: false

  attr :hint_as_error, :boolean,
    default: false,
    doc: "When true, surface validation errors by reddening the hint instead of listing them."

  attr :rest, :global, include: ~w(autocomplete required spellcheck)
  slot :hint

  def password_input(assigns) do
    assigns = assign(assigns, :has_error, field_has_error?(assigns.field))

    ~H"""
    <fieldset class="fieldset">
      <.field_label :if={@label} for={@field.id} show_required={@show_required}>
        {@label}
      </.field_label>
      <div class="relative">
        <input
          type="password"
          name={@field.name}
          id={@field.id}
          value={Phoenix.HTML.Form.normalize_value("password", @field.value)}
          aria-describedby={@hint != [] && "#{@field.id}_hint"}
          aria-invalid={@has_error && "true"}
          class={[input_class(@field), "pe-10"]}
          {@rest}
        />
        <FormComponents.password_visibility_toggle for={@field.id} />
      </div>
      <p
        :if={@hint != []}
        id={"#{@field.id}_hint"}
        role={@hint_as_error && @has_error && "alert"}
        class={[
          "text-sm mt-1",
          if(@hint_as_error && @has_error, do: "text-rose-600", else: "text-zinc-500")
        ]}
      >
        {render_slot(@hint)}
      </p>
      <.field_errors :if={not @hint_as_error} field={@field} />
    </fieldset>
    """
  end

  attr :for, :string, default: nil
  attr :show_required, :boolean, default: false
  slot :inner_block, required: true

  defp field_label(assigns) do
    ~H"""
    <label for={@for} class="block text-base font-header font-normal leading-6 text-zinc-800">
      {render_slot(@inner_block)}
      <span
        :if={@show_required}
        class="text-rose-600"
        title="Required"
        aria-hidden="true"
      >*</span>
    </label>
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true

  defp field_errors(assigns) do
    errors =
      if Phoenix.Component.used_input?(assigns.field) do
        Enum.map(assigns.field.errors, &KjogviWeb.BaseComponents.translate_error/1)
      else
        []
      end

    assigns = assign(assigns, :errors, errors)

    ~H"""
    <p :for={msg <- @errors} class="mt-0 flex gap-3 text-sm leading-6 text-rose-600">
      {msg}
    </p>
    """
  end

  defp field_has_error?(field) do
    Phoenix.Component.used_input?(field) and field.errors != []
  end

  defp input_class(field) do
    errors? = field_has_error?(field)

    [
      "mt-0 block w-full rounded-md text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6",
      if(errors?,
        do: "border-rose-400 focus:border-rose-400",
        else: "border-zinc-300 focus:border-zinc-400"
      )
    ]
  end
end
