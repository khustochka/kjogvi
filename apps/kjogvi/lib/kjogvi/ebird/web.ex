defmodule Kjogvi.Ebird.Web do
  @moduledoc """
  Operations with eBird web.
  """

  alias Kjogvi.Users.User
  alias Kjogvi.Ebird.Web.Client
  alias Kjogvi.Ebird.Web.Checklist
  alias Kjogvi.Birding
  alias Kjogvi.Types

  @actions %{
    preload: {:ebird_preload_progress, "eBird preload: "}
  }

  @doc """
  Preload user's checklists from eBird. Select only those that are not yet imported.
  """
  @spec preload_new_checklists_for_user(Client.Login.credentials()) ::
          Types.result([Checklist.Meta.t()])
  @spec preload_new_checklists_for_user(Client.Login.credentials(), keyword()) ::
          Types.result([Checklist.Meta.t()])
  def preload_new_checklists_for_user(user, opts \\ []) do
    import_id = {:preload, opts[:import_id]}
    new_opts = Keyword.put(opts, :import_id, import_id)

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

  def subscribe_progress(action, import_id) when is_map_key(@actions, action) do
    Phoenix.PubSub.subscribe(Kjogvi.PubSub, progress_key({action, import_id}))
  end

  def broadcast_progress({_action, nil}, _message) do
    :ok
  end

  def broadcast_progress({action, _import_id} = key, message) when is_map_key(@actions, action) do
    {tag, prefix} = @actions[action]

    Phoenix.PubSub.broadcast(
      Kjogvi.PubSub,
      progress_key(key),
      {tag, %{message: prefix <> message}}
    )
  end

  defp progress_key({action, import_id}) do
    "ebird:web:#{action}:progress:#{import_id}"
  end
end
