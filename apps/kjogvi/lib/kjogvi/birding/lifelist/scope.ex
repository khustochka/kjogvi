defmodule Kjogvi.Birding.Lifelist.Scope do
  @moduledoc """
  A structure that represents the base scope of observations selectedfor the Lifelist:
  user and whether to include private observations.
  """

  alias Kjogvi.Birding.Lifelist

  @type t() :: %__MODULE__{user: %{id: integer()}, include_private: boolean()}

  @enforce_keys [:user]

  defstruct user: nil, include_private: false

  def from_scope(scope) do
    %{
      user: user,
      main_user: main_user,
      private_view: private_view
    } = scope

    observer =
      if private_view do
        user
      else
        main_user
      end

    %Lifelist.Scope{user: observer, include_private: private_view}
  end
end
