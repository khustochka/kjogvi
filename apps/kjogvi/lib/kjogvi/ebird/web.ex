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
  @spec preload_new_checklists_for_user(Client.Login.credentials()) ::
          Types.result([Checklist.Meta.t()])
  @spec preload_new_checklists_for_user(Client.Login.credentials(), keyword()) ::
          Types.result([Checklist.Meta.t()])
  def preload_new_checklists_for_user(user, opts \\ []) do
    import_id = {:preload, opts[:import_id]}
    new_opts = opts |> Keyword.put(:import_id, import_id)

    if User.ebird_configured_async?(user) do
      with {:ok, checklists} <- Client.preload_checklists(user.extras.ebird, new_opts) do
        broadcast_progress(new_opts[:import_id], "Filtering for new checklists...")

        {:ok, Birding.find_new_checklists(user, checklists)}
        |> tap(fn {:ok, checklists} ->
          broadcast_progress(
            new_opts[:import_id],
            "eBird preload done: #{length(checklists)} new checklists."
          )
        end)
      end
    else
      {:error, "User does not have eBird configuration."}
    end
  end

  def subscribe_progress(action, import_id) do
    Phoenix.PubSub.subscribe(Kjogvi.PubSub, progress_key({action, import_id}))
  end

  def broadcast_progress({_action, nil}, _message) do
    :ok
  end

  def broadcast_progress({action, import_id}, message) do
    Phoenix.PubSub.broadcast(
      Kjogvi.PubSub,
      progress_key({action, import_id}),
      {"ebird_#{action}_progress", %{message: prefix(action) <> message}}
    )
  end

  defp progress_key({action, import_id}) do
    "ebird:web:#{action}:progress:#{import_id}"
  end

  defp prefix(action) do
    case action do
      :preload -> "eBird preload: "
    end
  end
end
