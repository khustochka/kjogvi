defmodule Kjogvi.Store.ChecklistsPreload do
  @moduledoc """
  Store for preloaded checklist metadata.
  """

  @ets_table_name :ebird_checklists_preload

  def init do
    :ets.new(@ets_table_name, [:set, :named_table, :public])
  end

  def last_preload_time do
    :ets.lookup(@ets_table_name, :last_preload_time)
    |> extract()
  end

  def preloaded_checklists do
    :ets.lookup(@ets_table_name, :preloaded_checklists)
    |> extract([])
  end

  def reset_preloads do
    :ets.delete(@ets_table_name, :preloaded_checklists)
    :ets.delete(@ets_table_name, :last_preload_time)
  end

  def store_checklists(checklists) do
    :ets.insert(@ets_table_name, [
      {:preloaded_checklists, checklists},
      {:last_preload_time, DateTime.utc_now()}
    ])
  end

  defp extract(list, default \\ nil) do
    case list do
      [] -> default
      [{_, smth}] -> smth
    end
  end
end
