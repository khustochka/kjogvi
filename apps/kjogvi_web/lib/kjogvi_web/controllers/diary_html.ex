defmodule KjogviWeb.DiaryHTML do
  use KjogviWeb, :html

  import KjogviWeb.DiaryComponents

  embed_templates "diary_html/*"
end
