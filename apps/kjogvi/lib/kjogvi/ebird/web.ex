defmodule Kjogvi.Ebird.Web do
  @moduledoc """
  Operations with eBird web.
  """

  alias Kjogvi.Accounts
  alias Kjogvi.Accounts.User
  alias Kjogvi.Accounts.UserPreferences
  alias Kjogvi.Ebird.Web.Client
  alias Kjogvi.Ebird.Web.Checklist
  alias Kjogvi.Birding
  alias Kjogvi.Types

  @doc """
  The user's eBird login credentials from their preferences, or an error tuple
  when async eBird sync is not configured.
  """
  @spec ebird_credentials(User.t()) ::
          {:ok, Client.Login.credentials()} | {:error, %{message: String.t()}}
  def ebird_credentials(user) do
    preferences = Accounts.get_user_preferences(user)

    if UserPreferences.ebird_configured_async?(preferences) do
      {:ok, %{username: preferences.ebird.username, password: preferences.ebird.password}}
    else
      {:error, %{message: "User does not have eBird configuration."}}
    end
  end

  @doc """
  Preload the user's checklists from eBird using resolved `credentials`. Selects
  only those not yet imported.
  """
  @spec preload_new_checklists_for_user(User.t(), Client.Login.credentials()) ::
          Types.result([Checklist.Meta.t()])
  @spec preload_new_checklists_for_user(User.t(), Client.Login.credentials(), keyword()) ::
          Types.result([Checklist.Meta.t()])
  def preload_new_checklists_for_user(user, credentials, opts \\ []) do
    broadcast_key = opts[:broadcast_key]

    with {:ok, checklists} <- Client.preload_checklists(credentials, opts) do
      broadcast_progress(broadcast_key, %{message: "Finding new checklists..."})

      # The "done" message is surfaced by the job's :ok lifecycle event, so no
      # completion progress is broadcast here.
      {:ok, Birding.find_new_checklists(user, checklists)}
    end
  end

  def broadcast_progress(nil, _message) do
    :ok
  end

  def broadcast_progress(broadcast_key, data) do
    Phoenix.PubSub.broadcast(
      Kjogvi.PubSub,
      Kjogvi.Util.PubSubTopic.for_key(broadcast_key),
      {:progress, broadcast_key, data}
    )
  end
end
