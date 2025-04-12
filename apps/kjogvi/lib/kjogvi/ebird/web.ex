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
  def preload_new_checklists_for_user(user) do
    if User.ebird_configured_async?(user) do
      with {:ok, checklists} <- Client.preload_checklists(user.extras.ebird) do
        {:ok, Birding.find_new_checklists(user, checklists)}
      end
    else
      {:error, "User does not have eBird configuration."}
    end
  end
end
