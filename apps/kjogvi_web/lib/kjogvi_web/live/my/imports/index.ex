defmodule KjogviWeb.Live.My.Imports.Index do
  @moduledoc false

  use KjogviWeb, :live_view

  alias KjogviWeb.Live.My.Imports

  @imports [
    {Imports.Legacy, "Legacy Import", "legacy-import"},
    {Imports.Ebird, "eBird preload", "ebird-import"}
  ]

  on_mount {Imports.Legacy, :attach}
  on_mount {Imports.Ebird, :attach}

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Import Tasks")}
  end

  def render(assigns) do
    assigns = assign(assigns, :imports, @imports)

    ~H"""
    <.h1>Import Tasks</.h1>

    <div class="lg:flex lg:flex-wrap lg:gap-8 lg:items-start">
      <div
        :for={{module, header, id} <- @imports}
        class="border border-slate-300 rounded-lg p-6 mb-8 lg:mb-0 lg:basis-15/31 lg:grow-0"
      >
        <.h2>{header}</.h2>
        <.live_component module={module} user={@current_scope.current_user} id={id} />
      </div>
    </div>
    """
  end
end
