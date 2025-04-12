defmodule Kjogvi.Types do
  @moduledoc """
  Universal types.
  """

  @type result(t) :: {:ok, t} | {:error, String.t()}
end
