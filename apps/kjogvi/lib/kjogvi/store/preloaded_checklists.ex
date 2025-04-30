defmodule Kjogvi.Store.ChecklistsPreload do
  @moduledoc """
  Store for preloaded checklist metadata.
  """

  use GenServer

  defstruct last_preload_time: nil, preloaded_checklists: []

  def last_preload_time do
    GenServer.call(__MODULE__, :last_preload_time)
  end

  def preloaded_checklists do
    GenServer.call(__MODULE__, :preloaded_checklists)
  end

  def reset_preloads do
    GenServer.cast(__MODULE__, :reset_preloads)
  end

  def store_checklists(checklists) do
    GenServer.cast(__MODULE__, {:store_checklists, checklists})
  end

  # Callbacks

  @impl true
  def init(_) do
    {:ok, struct(__MODULE__)}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, {}, opts)
  end

  @impl true
  def handle_call(:last_preload_time, _from, state) do
    {:reply, state.last_preload_time, state}
  end

  def handle_call(:preloaded_checklists, _from, state) do
    {:reply, state.preloaded_checklists, state}
  end

  @impl true
  def handle_cast(:reset_preloads, _state) do
    {:noreply, struct(__MODULE__)}
  end

  def handle_cast({:store_checklists, checklists}, _state) do
    state =
      struct(
        __MODULE__,
        %{preloaded_checklists: checklists, last_preload_time: DateTime.utc_now()}
      )

    {:noreply, state}
  end
end
