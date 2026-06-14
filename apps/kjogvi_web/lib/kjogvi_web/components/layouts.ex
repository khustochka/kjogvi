defmodule KjogviWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "public" layout is the default app layout on both
  `use KjogviWeb, :controller` and `use KjogviWeb, :live_view`; the "private"
  layout is used for the `:private` and `:admin` sections (see `for_scope/1`).
  """

  use KjogviWeb, :html

  import KjogviWeb.Partials

  embed_templates "layouts/*"

  @doc """
  Picks the app layout for a scope based on its section.

  `:community` and `:user` sections render the public chrome; `:private` and
  `:admin` render the private chrome. This is the single place layout is decided
  from the scope — callers derive it, they don't choose it.
  """
  def for_scope(%{section: section}) when section in [:private, :admin], do: :private
  def for_scope(%{section: _}), do: :public
end
