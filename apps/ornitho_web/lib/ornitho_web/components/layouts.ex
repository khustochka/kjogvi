defmodule OrnithoWeb.Layouts do
  @moduledoc false

  use OrnithoWeb, :html

  embed_templates "layouts/*"

  defp csp_nonce(conn, type) when type in [:script, :style, :img] do
    csp_nonce_assign_key = conn.private.csp_nonce_assign_key[type]
    conn.assigns[csp_nonce_assign_key]
  end

  defp asset_path(conn, asset) when asset in [:css, :js] do
    hash = OrnithoWeb.Assets.current_hash(asset)

    if function_exported?(conn.private.phoenix_router, :__ornitho_web_prefix__, 0) do
      prefix = conn.private.phoenix_router.__ornitho_web_prefix__()

      Phoenix.VerifiedRoutes.unverified_path(
        conn,
        conn.private.phoenix_router,
        "#{prefix}/#{asset}-#{hash}"
      )
    else
      apply(
        conn.private.phoenix_router.__helpers__(),
        :ornitho_web_asset_path,
        [conn, asset, hash]
      )
    end
  end
end
