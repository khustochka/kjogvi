defmodule Kjogvi.Settings.UserSetting.Query do
  @moduledoc """
  Composable queries over `Kjogvi.Settings.UserSetting`.
  """

  import Ecto.Query

  alias Kjogvi.Settings.UserSetting

  @doc """
  Selects the `user_id`s among `user_ids` whose `key` is set to the boolean `value`.
  """
  def user_ids_with_flag(user_ids, key, value) do
    from(s in UserSetting,
      where: s.user_id in ^user_ids and s.key == ^key and s.value == ^value,
      select: s.user_id
    )
  end
end
