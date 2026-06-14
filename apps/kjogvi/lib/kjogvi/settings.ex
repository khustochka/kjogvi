defmodule Kjogvi.Settings do
  @moduledoc """
  Site settings.
  """

  @prefix "settings:"
  @main_user_key "main_user"

  import Ecto.Query

  alias Kjogvi.Repo
  alias Kjogvi.Accounts


  defp key(key), do: @prefix <> key
end
