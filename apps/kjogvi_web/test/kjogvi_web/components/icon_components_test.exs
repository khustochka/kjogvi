defmodule KjogviWeb.IconComponentsTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias KjogviWeb.IconComponents

  describe "car-slash" do
    test "each instance references its own mask" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <IconComponents.icon name="car-slash" class="h-4 w-4" />
        <IconComponents.icon name="car-slash" class="h-4 w-4" />
        """)

      doc = LazyHTML.from_fragment(html)
      mask_ids = doc |> LazyHTML.query("mask") |> LazyHTML.attribute("id")
      mask_refs = doc |> LazyHTML.query("g[mask]") |> LazyHTML.attribute("mask")

      assert length(Enum.uniq(mask_ids)) == 2
      assert mask_refs == Enum.map(mask_ids, &"url(##{&1})")
    end
  end
end
