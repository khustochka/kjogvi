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
  The section the request operates in. It determines whose data is visible and
  whether private data is included:

    * `:community` - aggregate public data across all users (the default section).
    * `:user` - the public data of a specific `subject_user`.
    * `:private` - all data, including private, of the logged-in `current_user`.
    * `:admin` - administrative section.
  """
  @type section() :: :community | :user | :private | :admin

  @type t() :: %__MODULE__{
          current_user: Kjogvi.Accounts.User.t() | nil,
          section: section(),
          subject_user: Kjogvi.Accounts.User.t() | nil
        }

  defstruct current_user: nil, section: :community, subject_user: nil
end
