defmodule Ornitho.Query.Utils do
  @like_special_symbols ~r/(%|_|\\)/
  @like_replace_pattern "\\\\\\1"

  def sanitize_like(str) do
    String.replace(str, @like_special_symbols, @like_replace_pattern)
  end
end
