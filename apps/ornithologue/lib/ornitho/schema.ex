defmodule Ornitho.Schema do
  @moduledoc """
  Schema for an Ornitho model. The only thing it does is sets the default type
  of timestamps to UTC datetime with milliseconds.
  """

  defmacro __using__(_) do
    quote do
      use Ecto.Schema

      @timestamps_opts [type: :utc_datetime_usec]
    end
  end
end
