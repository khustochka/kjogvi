defmodule Kjogvi.Store.ChecklistPreload do
  @moduledoc """
  Store for preloaded checklist metadata.
  """

  use GenServer

  defstruct last_preload_time: nil, checklists: []

  def new(checklists) do
    struct(
      __MODULE__,
      %{checklists: checklists, last_preload_time: DateTime.utc_now()}
    )
  end

  def get_preloads(user) do
    GenServer.call(__MODULE__, {:get_preloads, user})
  end

  def reset_preloads(user) do
    GenServer.cast(__MODULE__, {:reset_preloads, user})
  end

  def store_checklists(user, checklists) do
    GenServer.cast(__MODULE__, {:store_checklists, user, checklists})
  end

  # Callbacks

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, {}, opts)
  end

  @impl true
  def handle_call({:get_preloads, user}, _from, state) do
    {:reply, Map.get(state, user.id, struct(__MODULE__)), state}
  end

  @impl true
  def handle_cast({:reset_preloads, user}, state) do
    {:noreply, Map.put(state, user.id, struct(__MODULE__))}
  end

  def handle_cast({:store_checklists, user, checklists}, state) do
    {:noreply,
     state
     |> Map.put(user.id, new(checklists))}
  end
end
