defmodule Kjogvi.Settings do
  @moduledoc """
  Site-wide settings, feature flags, and kill switches.

  Each setting is exposed as its own intention-revealing function
  (e.g. `registration_disabled?/0`) so call sites read clearly and never depend
  on how the value is stored. Values are resolved through the private `get/2`
  from application config, falling back to a hardcoded default:

      config :kjogvi, Kjogvi.Settings, registration_disabled: true

  This `get/2` is the single seam to replace when settings move to the database;
  the public functions and their callers stay unchanged.
  """

  @doc """
  Whether new user registration is closed.
  """
  def registration_disabled? do
    get(:registration_disabled, false)
  end

  @doc """
  Whether the forgot/reset password flow is closed.
  """
  def forgot_reset_password_disabled? do
    get(:forgot_reset_password_disabled, false)
  end

  @doc """
  Whether the email/account confirmation flow is closed.
  """
  def confirmation_disabled? do
    get(:confirmation_disabled, false)
  end

  @doc """
  The `Ornitho.Importer` module the bootstrap seeds taxonomy from.
  """
  def default_taxonomy_importer do
    get(:default_taxonomy_importer, nil)
  end

  @doc """
  The site default taxonomy as a `"slug/version"` book signature, derived from
  `default_taxonomy_importer/0`. Stamped on new users at registration; `nil`
  when no default importer is configured.
  """
  def default_taxonomy do
    case default_taxonomy_importer() do
      nil -> nil
      importer -> "#{importer.slug()}/#{importer.version()}"
    end
  end

  # Resolution layer. The only place that knows where settings come from --
  # swap this for a DB lookup later without touching any public function.
  defp get(key, default) do
    :kjogvi
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(key, default)
  end
end
