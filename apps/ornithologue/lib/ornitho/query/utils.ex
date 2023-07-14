defmodule Ornitho.Query.Utils do
  def sanitize_like(str) do
    String.replace(str, ~r/(%|_|\\)/, "\\\\\\1")
  end
end
