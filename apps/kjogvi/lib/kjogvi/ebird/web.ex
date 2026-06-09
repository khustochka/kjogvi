defmodule Kjogvi.Ebird.Web do
  @moduledoc """
  Operations with eBird web.
  """

  alias Kjogvi.Users.User
  alias Kjogvi.Ebird.Web.Client
  alias Kjogvi.Ebird.Web.Checklist
  alias Kjogvi.Birding
  alias Kjogvi.Types

  @doc """
  Preload user's checklists from eBird. Select only those that are not yet imported.
  """
  @spec preload_new_checklists_for_user(User.t()) ::
          Types.result([Checklist.Meta.t()])
  @spec preload_new_checklists_for_user(User.t(), keyword()) ::
          Types.result([Checklist.Meta.t()])
  def preload_new_checklists_for_user(user, opts \\ []) do
    broadcast_key = opts[:broadcast_key]

    if User.ebird_configured_async?(user) do
      with {:ok, checklists} <- Client.preload_checklists(user.extras.ebird, opts) do
        broadcast_progress(broadcast_key, %{message: "Finding new checklists..."})

        {:ok, Birding.find_new_checklists(user, checklists)}
        |> tap(fn {:ok, checklists} ->
          broadcast_progress(
            broadcast_key,
            %{message: "eBird preload done: #{length(checklists)} new checklists."}
          )
        end)
      end
    else
      {:error, %{message: "User does not have eBird configuration."}}
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
