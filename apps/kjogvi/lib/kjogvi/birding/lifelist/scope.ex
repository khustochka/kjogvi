defmodule Kjogvi.Birding.Lifelist.Scope do
  @moduledoc """
  A structure that represents the base scope of observations selectedfor the Lifelist:
  user and whether to include private observations.
  """

  alias Kjogvi.Birding.Lifelist

  @type t() :: %__MODULE__{
          user: %{id: integer(), extras: map()} | nil,
          include_private: boolean()
        }

  defstruct user: nil, include_private: false

  @doc """
  Builds the lifelist scope from the application `Kjogvi.Scope`.

  The observed user and private visibility are derived from the section:

    * `:private` / `:admin` - the logged-in user views their own list,
      including private observations.
    * `:user` - the public list of the scope's `subject_user`.
    * `:community` - the aggregate public list across all users (no `user`).
  """
  def from_scope(%{section: section, current_user: user})
      when section in [:private, :admin] do
    %Lifelist.Scope{user: user, include_private: true}
  end

  def from_scope(%{section: :user, subject_user: subject_user}) do
    %Lifelist.Scope{user: subject_user, include_private: false}
  end

  def from_scope(%{section: :community}) do
    %Lifelist.Scope{user: nil, include_private: false}
  end
end
