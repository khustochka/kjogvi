defmodule Kjogvi.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The scope allows public interfaces to receive
  information about the caller, such as if the call is initiated from an
  end-user, and if so, which user. Additionally, such a scope can carry fields
  such as "super user" or other privileges for use as authorization, or to
  ensure specific code paths can only be access for a given scope.

  It is useful for logging as well as for scoping pubsub subscriptions and
  broadcasts when a caller subscribes to an interface or performs a particular
  action.

  Feel free to extend the fields on this struct to fit the needs of
  growing application requirements.
  """

  @typedoc """
  The area the request operates in. It determines whose data is visible and
  whether private data is included:

    * `:community` - aggregate public data across all users (the default area).
    * `:user` - the public data of a specific `subject_user`.
    * `:private` - all data, including private, of the logged-in `current_user`.
    * `:admin` - administrative area: all data across all users, including
      private.
  """
  @type area() :: :community | :user | :private | :admin

  @typedoc """
  Data visibility implied by the area: `:private` exposes the subject user's
  private data, `:public` only their public data.
  """
  @type visibility() :: :public | :private

  @type t() :: %__MODULE__{
          current_user: Kjogvi.Accounts.User.t() | nil,
          area: area(),
          subject_user: Kjogvi.Accounts.User.t() | nil
        }

  defstruct current_user: nil, area: :community, subject_user: nil

  @doc """
  The user whose data the scope selects, or `nil` for an aggregate across all
  users:

    * `:private` — the logged-in `current_user`.
    * `:user` — the `subject_user`.
    * `:community` / `:admin` — `nil` (aggregate of all users; `:admin` includes
      private data, see `visibility/1`).
  """
  @spec subject_user(t()) :: Kjogvi.Accounts.User.t() | nil
  def subject_user(%__MODULE__{area: :private, current_user: user}), do: user
  def subject_user(%__MODULE__{area: :user, subject_user: user}), do: user
  def subject_user(%__MODULE__{area: area}) when area in [:community, :admin], do: nil

  @doc """
  Whether the scope may see private data: `:private` for the owner's own area
  (`:private`) and the administrative area (`:admin`), `:public` otherwise.
  """
  @spec visibility(t()) :: visibility()
  def visibility(%__MODULE__{area: area}) when area in [:private, :admin], do: :private
  def visibility(%__MODULE__{area: area}) when area in [:user, :community], do: :public
end
