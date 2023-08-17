defmodule KjogviWeb.Scrivener.Template.Tailwind do
  @moduledoc ~S"""
  Tailwind template for Scrivener pagination.
  """

  use Scrivener.Phoenix.Template
  alias Scrivener.Phoenix.Gap
  alias Scrivener.Phoenix.Page
  import Scrivener.Phoenix.Page
  import Scrivener.Phoenix.Gettext

  @shared_li_wrap_class "page-item py-2 px-4"
  @default_page_class "border"
  @default_gap_class "disabled border-0"

  defp li_wrap(content, options) do
    {_old_value, options} =
      options
      |> Keyword.get_and_update(:class, fn current -> {current, Enum.join([@shared_li_wrap_class, current], " ")} end)

    content_tag(:li, content, options)
  end

  defp build_element(text, href, options, child_html_attrs, parent_html_attrs \\ []) do
    text
    |> link_callback(options).(Keyword.merge(child_html_attrs, [to: href, class: "page-link"]))
    |> li_wrap(parent_html_attrs)
  end

  def build_page_element(text, href, options, child_html_attrs, parent_html_attrs \\ []) do
    {_old_value, parent_html_attrs} =
      parent_html_attrs
      |> Keyword.get_and_update(:class, fn current -> {current, Enum.join([@default_page_class, current], " ")} end)

    build_element(text, href, options, child_html_attrs, parent_html_attrs)
  end

  @impl Scrivener.Phoenix.Template
  def first_page(_page, %Scrivener.Page{page_number: 1}, %{}), do: nil

  def first_page(page = %Page{}, _spage, options = %{}) do
    build_page_element(options.labels.first, page.href, options, title: dgettext("scrivener_phoenix", "First page"))
  end

  @impl Scrivener.Phoenix.Template
  if false do
    def last_page(page = %Page{}, spage = %Scrivener.Page{}, options = %{}) do
      unless Page.last_page?(page, spage) do
        build_page_element(options.labels.last, page.href, options, title: dgettext("scrivener_phoenix", "Last page"))
      end
    end
  else
    def last_page(%Page{}, %Scrivener.Page{page_number: no, total_pages: no}, %{}), do: nil

    def last_page(page = %Page{}, _spage, options = %{}) do
      build_page_element(options.labels.last, page.href, options, title: dgettext("scrivener_phoenix", "Last page"))
    end
  end

  @impl Scrivener.Phoenix.Template
  def prev_page(nil, %{}), do: nil

  def prev_page(page = %Page{}, options = %{}) do
    build_page_element(options.labels.prev, page.href, options, title: dgettext("scrivener_phoenix", "Previous page"), rel: "prev")
  end

  @impl Scrivener.Phoenix.Template
  def next_page(nil, %{}), do: nil

  def next_page(page = %Page{}, options = %{}) do
    build_page_element(options.labels.next, page.href, options, title: dgettext("scrivener_phoenix", "Next page"), rel: "next")
  end

  @impl Scrivener.Phoenix.Template
  if false do
    def page(page = %Page{}, spage = %Scrivener.Page{}, options = %{}) do
      if Page.current?(page, spage) do
        build_page_element(page.no, "#", options, [], class: "active")
      else
        build_page_element(page.no, page.href, options, handle_rel(page, spage))
      end
    end
  else
    def page(page = %Page{no: no}, %Scrivener.Page{page_number: no}, options = %{}) do
      build_page_element(page.no, "#", options, [], class: "active")
    end

    def page(page = %Page{}, spage = %Scrivener.Page{}, options = %{}) do
      build_page_element(page.no, page.href, options, handle_rel(page, spage))
    end
  end

  def page(%Gap{}, %Scrivener.Page{}, options = %{}) do
    build_element("…", "#", options, [], class: @default_gap_class)
  end

  @impl Scrivener.Phoenix.Template
  def wrap(links) do
    content_tag(:nav) do
      content_tag(:ul, class: "pagination flex gap-2") do
        links
      end
    end
  end
end
