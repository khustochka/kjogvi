defmodule Kjogvi.Imports.ImportLog.Query do
  @moduledoc """
  Queries for `Kjogvi.Imports.ImportLog`.
  """

  import Ecto.Query

  alias Kjogvi.Imports.ImportLog

  def by_user(query \\ ImportLog, user) do
    from l in query, where: l.user_id == ^user.id
  end

  def newest_first(query \\ ImportLog) do
    from l in query, order_by: [desc: l.id]
  end
end
