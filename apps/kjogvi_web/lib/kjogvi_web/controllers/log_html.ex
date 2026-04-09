defmodule KjogviWeb.LogHTML do
  use KjogviWeb, :html

  import KjogviWeb.LogComponents

  embed_templates "log_html/*"
end
