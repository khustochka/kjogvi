defmodule Kjogvi.Birding.Lifelist.Scope do
  @moduledoc """
  A structure that represents the base scope of observations selectedfor the Lifelist:
  user and whether to include private observations.
  """

  @type t() :: %__MODULE__{user: %{id: integer()}, include_private: boolean()}

  @enforce_keys [:user]

  defstruct user: nil, include_private: false
end
