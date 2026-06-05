defmodule Kjogvi.Util.TokenTest do
  use ExUnit.Case, async: true

  alias Kjogvi.Util.Token

  test "generates a token of the requested length" do
    assert String.length(Token.generate()) == 12
    assert String.length(Token.generate(8)) == 8
  end

  test "uses only url-safe lowercase base32 characters" do
    assert Token.generate(64) =~ ~r/\A[0-9a-hjkmnp-tv-z]+\z/
  end

  test "is practically unique across calls" do
    tokens = for _ <- 1..1000, do: Token.generate()
    assert length(Enum.uniq(tokens)) == 1000
  end
end
