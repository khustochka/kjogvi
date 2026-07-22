defmodule Kjogvi.Imports.ImportError.Query do
  @moduledoc """
  Queries for `Kjogvi.Imports.ImportError`.
  """

  import Ecto.Query

  alias Kjogvi.Imports.ImportError

  def by_import_log(query \\ ImportError, import_log_id) do
    from e in query, where: e.import_log_id == ^import_log_id
  end

  def oldest_first(query \\ ImportError) do
    from e in query, order_by: [asc: e.id]
  end
end
