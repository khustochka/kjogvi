defmodule Kjogvi.Users.User.Extras.LogSetting do
  @moduledoc """
  A single log setting entry: controls whether life and/or year list entries
  are shown for a given location in the log.

  A `location_id` of `nil` represents the World scope.
  """

  use Kjogvi.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :location_id, :integer
    field :life, :boolean, default: true
    field :year, :boolean, default: true
  end

  def changeset(log_setting, attrs) do
    log_setting
    |> cast(attrs, [:location_id, :life, :year])
  end
end
