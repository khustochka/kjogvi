defmodule KjogviWeb.Live.Components.Autocomplete.Highlight do
  @moduledoc """
  Helpers for rendering the matched portion of the search term inside
  autocomplete result rows.
  """

  use Phoenix.Component

  attr :text, :string, required: true
  attr :term, :string, default: nil

  def highlighted_text(assigns) do
    assigns = assign(assigns, :segments, segments(assigns.text, assigns.term))

    ~H"""
    <span phx-no-format><%= for segment <- @segments do %><.segment segment={segment} /><% end %></span>
    """
  end

  defp segment(%{segment: {text, true}} = assigns) do
    assigns = assign(assigns, :text, text)
    ~H"<strong>{@text}</strong>"
  end

  defp segment(%{segment: {text, false}} = assigns) do
    assigns = assign(assigns, :text, text)
    ~H"{@text}"
  end

  defp segments(text, nil), do: [{text, false}]
  defp segments(text, ""), do: [{text, false}]

  defp segments(text, term) do
    regex = Regex.compile!(Regex.escape(term), "i")
    parts = Regex.split(regex, text, include_captures: true)
    downcased = String.downcase(term)

    Enum.map(parts, fn part ->
      {part, String.downcase(part) == downcased}
    end)
  end
end
