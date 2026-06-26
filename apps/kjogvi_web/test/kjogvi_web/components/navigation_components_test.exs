defmodule KjogviWeb.NavigationComponentsTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias KjogviWeb.NavigationComponents

  describe "action_button/1" do
    test "renders a primary action button by default" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <NavigationComponents.action_button navigate="/checklists/new">
          New Checklist
        </NavigationComponents.action_button>
        """)

      assert html =~ "New Checklist"
      assert html =~ "bg-blue-600"
      assert html =~ "text-white"
      assert html =~ ~s(href="/checklists/new")
    end

    test "renders a secondary action button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <NavigationComponents.action_button navigate="/checklists" variant="secondary">
          Cancel
        </NavigationComponents.action_button>
        """)

      assert html =~ "Cancel"
      assert html =~ "bg-gray-200"
      assert html =~ "text-gray-800"
    end

    test "renders with an icon" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <NavigationComponents.action_button navigate="/checklists/new" icon="hero-plus">
          New Checklist
        </NavigationComponents.action_button>
        """)

      assert html =~ "hero-plus"
      assert html =~ "New Checklist"
    end

    test "renders without an icon" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <NavigationComponents.action_button navigate="/checklists">
          Cancel
        </NavigationComponents.action_button>
        """)

      refute html =~ "<svg"
      assert html =~ "Cancel"
    end

    test "supports patch navigation" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <NavigationComponents.action_button patch="/checklists/new">
          New Checklist
        </NavigationComponents.action_button>
        """)

      assert html =~ ~s(href="/checklists/new")
      assert html =~ "data-phx-link=\"patch\""
    end
  end

  describe "breadcrumb_link/1" do
    test "renders a breadcrumb link with forest green color" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <NavigationComponents.breadcrumb_link href="/locations">
          All locations
        </NavigationComponents.breadcrumb_link>
        """)

      assert html =~ "All locations"
      assert html =~ "text-forest-600"
      assert html =~ "no-underline"
      assert html =~ "hover:underline"
    end

    test "supports patch navigation" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <NavigationComponents.breadcrumb_link patch="/lifelist">
          World
        </NavigationComponents.breadcrumb_link>
        """)

      assert html =~ "World"
      assert html =~ "data-phx-link=\"patch\""
    end
  end

  describe "icon_link/1" do
    test "renders an icon with aria-label for accessibility" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <NavigationComponents.icon_link
          navigate="/checklists/1/edit"
          icon="hero-pencil-square"
          label="Edit checklist"
        />
        """)

      assert html =~ "hero-pencil-square"
      assert html =~ ~s(aria-label="Edit checklist")
      assert html =~ ~s(href="/checklists/1/edit")
    end

    test "supports custom class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <NavigationComponents.icon_link
          navigate="/checklists/1"
          icon="hero-clipboard-document-list"
          label="View checklist"
          class="text-gray-400"
        />
        """)

      assert html =~ "text-gray-400"
    end
  end
end
