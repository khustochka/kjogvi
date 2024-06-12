defmodule KjogviWeb.Partials do
  @moduledoc """
  Top level partials.
  """

  use KjogviWeb, :html

  import KjogviWeb.AdminMenuComponents

  require Kjogvi.Config

  embed_templates "partials/*"
end
