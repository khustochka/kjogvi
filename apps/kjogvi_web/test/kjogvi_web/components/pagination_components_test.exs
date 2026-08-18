defmodule KjogviWeb.PaginationComponentsTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias KjogviWeb.PaginationComponents

  defp meta(current_page, total_pages) do
    %Flop.Meta{
      current_page: current_page,
      total_pages: total_pages,
      has_previous_page?: current_page > 1,
      has_next_page?: current_page < total_pages
    }
  end

  defp render_pagination(meta) do
    assigns = %{meta: meta}

    rendered_to_string(~H"""
    <PaginationComponents.pagination meta={@meta} path={&"/things/page/#{&1}"} />
    """)
  end

  defp page_links(html) do
    html
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("a")
    |> Enum.map(&(&1 |> LazyHTML.attribute("href") |> List.first()))
  end

  describe "pagination/1" do
    test "renders nothing when everything fits on one page" do
      assert render_pagination(meta(1, 1)) |> String.trim() == ""
    end

    test "marks the current page instead of linking it" do
      html = render_pagination(meta(2, 3))

      assert html =~ ~s(aria-current="page")
      refute "/things/page/2" in page_links(html)
    end

    test "links neighbouring pages, first and last" do
      links = render_pagination(meta(5, 10)) |> page_links()

      assert "/things/page/3" in links
      assert "/things/page/7" in links
      assert "/things/page/1" in links
      assert "/things/page/10" in links
    end

    test "elides pages outside the window" do
      html = render_pagination(meta(5, 10))

      assert html =~ "…"
      refute "/things/page/2" in page_links(html)
      refute "/things/page/8" in page_links(html)
    end

    test "omits previous and next at the ends of the range" do
      first = render_pagination(meta(1, 3))
      refute first =~ ~s(rel="prev")
      assert first =~ ~s(rel="next")

      last = render_pagination(meta(3, 3))
      assert last =~ ~s(rel="prev")
      refute last =~ ~s(rel="next")
    end
  end
end
