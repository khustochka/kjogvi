defmodule KjogviWeb.Scrivener.Phoenix.Template do
  @moduledoc ~S"""
  Tailwind template for Scrivener pagination.
  """

  use Scrivener.Phoenix.Template
  alias Scrivener.Phoenix.Gap
  alias Scrivener.Phoenix.Page
  import Scrivener.Phoenix.Page
  use Gettext, backend: Scrivener.Phoenix.Gettext

  @shared_wrap_class "page-item text-center my-2"
  @link_wrap_class "border"
  @gap_wrap_class "disabled border-0"
  @shared_page_num_class "page-link inline-block whitespace-nowrap py-2 px-4 w-full h-full"
  @link_class "#{@shared_page_num_class} hover:bg-zinc-200 no-underline"
  @gap_class "inline-block py-2 px-2"

  defp li_wrap(content, options) do
    {_old_value, options} =
      options
      |> Keyword.get_and_update(:class, fn current ->
        {current, Enum.join([@shared_wrap_class, current], " ")}
      end)

    content_tag(:li, content, options)
  end

  defp build_element(text, href, options, child_html_attrs, parent_html_attrs) do
    text
    |> link_callback(options).(Keyword.merge(child_html_attrs, to: href, class: @link_class))
    |> li_wrap(parent_html_attrs)
  end

  def build_page_element(text, href, options, child_html_attrs, parent_html_attrs \\ []) do
    {_old_value, parent_html_attrs} =
      parent_html_attrs
      |> Keyword.get_and_update(:class, fn current ->
        {current, Enum.join([@link_wrap_class, current], " ")}
      end)

    build_element(text, href, options, child_html_attrs, parent_html_attrs)
  end

  @impl Scrivener.Phoenix.Template
  def first_page(_page, %Scrivener.Page{page_number: 1}, %{}), do: nil

  def first_page(%Page{} = page, _spage, %{} = options) do
    build_page_element(options.labels.first, page.href, options,
      title: dgettext("scrivener_phoenix", "First page")
    )
  end

  @impl Scrivener.Phoenix.Template
  def last_page(%Page{}, %Scrivener.Page{page_number: no, total_pages: no}, %{}), do: nil

  def last_page(%Page{} = page, _spage, %{} = options) do
    build_page_element(options.labels.last, page.href, options,
      title: dgettext("scrivener_phoenix", "Last page")
    )
  end

  @impl Scrivener.Phoenix.Template
  def prev_page(nil, %{}), do: nil

  def prev_page(%Page{} = page, %{} = options) do
    build_page_element(options.labels.prev, page.href, options,
      title: dgettext("scrivener_phoenix", "Previous page"),
      rel: "prev"
    )
  end

  @impl Scrivener.Phoenix.Template
  def next_page(nil, %{}), do: nil

  def next_page(%Page{} = page, %{} = options) do
    build_page_element(options.labels.next, page.href, options,
      title: dgettext("scrivener_phoenix", "Next page"),
      rel: "next"
    )
  end

  @impl Scrivener.Phoenix.Template
  def page(%Page{no: no} = page, %Scrivener.Page{page_number: no}, %{} = _options) do
    content_tag(:span, class: "#{@shared_page_num_class} active font-bold") do
      page.no
    end
    |> li_wrap(class: @link_wrap_class)

    # build_page_element(page.no, page.href, options, [], class: "active font-bold")
  end

  def page(%Page{} = page, %Scrivener.Page{} = spage, %{} = options) do
    build_page_element(page.no, page.href, options, handle_rel(page, spage))
  end

  def page(%Gap{}, %Scrivener.Page{}, %{} = _options) do
    content_tag(:span, class: @gap_class) do
      "…"
    end
    |> li_wrap(class: @gap_wrap_class)
  end

  @impl Scrivener.Phoenix.Template
  def wrap(links) do
    content_tag(:nav) do
      content_tag(:ul, class: "pagination sm:flex gap-2 mt-4") do
        links
      end
    end
  end
end
