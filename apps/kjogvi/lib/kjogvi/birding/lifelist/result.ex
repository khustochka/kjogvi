defmodule Kjogvi.Birding.Lifelist.Result do
  @moduledoc """
  Lifelist fetch result structure
  """

  alias Kjogvi.Birding.Lifelist

  @type t() :: %__MODULE__{}

  defstruct user: nil, filter: %Lifelist.Filter{}, list: [], total: 0, extras: %{}
end
