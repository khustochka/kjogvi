defmodule KjogviWeb.Live.My.Imports.Index do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Kjogvi.Accounts
  alias KjogviWeb.Live.My.Imports

  on_mount {Imports.Legacy, :attach}
  on_mount {Imports.Ebird, :attach}

  def mount(_params, _session, %{assigns: assigns} = socket) do
    {:ok,
     socket
     |> assign(:page_title, "Import Tasks")
     |> assign(
       :imports,
       Enum.filter(imports(), fn {_, _, _, condition_func} ->
         condition_func.(assigns.current_scope.current_user)
       end)
     )}
  end

  def render(assigns) do
    ~H"""
    <.h1>Import Tasks</.h1>

    <div class="lg:grid lg:grid-cols-2 lg:gap-6 lg:items-start">
      <div
        :for={{module, header, id, _} <- @imports}
        class="border border-slate-300 rounded-lg p-6 mb-8 lg:mb-0"
      >
        <.h2 class="mb-4!">{header}</.h2>
        <.live_component module={module} user={@current_scope.current_user} id={id} />
      </div>
    </div>
    """
  end

  defp imports do
    [
      {Imports.Legacy, "Legacy Import", "legacy-import", fn user -> Accounts.admin?(user) end},
      {Imports.Ebird, "eBird preload", "ebird-import", fn _ -> true end},
      {Imports.Locations, "Locations Import", "locations-import",
       fn user -> Accounts.admin?(user) end}
    ]
  end
end
