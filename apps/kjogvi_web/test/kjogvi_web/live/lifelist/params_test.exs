defmodule KjogviWeb.Live.Lifelist.ParamsTest do
  use Kjogvi.DataCase, async: true

  alias KjogviWeb.Live.Lifelist.Params
  alias Kjogvi.Birding.Lifelist.Opts

  test "no parameters" do
    opts = Params.to_filter(%{})
    assert opts == Opts.discombo([])
  end

  test "only valid year" do
    opts = Params.to_filter(%{"year_or_location" => "2024"})
    assert opts == Opts.discombo([year: 2024])
  end

  # test "only valid year", %{conn: conn} do
  #   opts = Params.to_filter(%{"year" => "2024"})
  #   assert opts == Opts.discombo([year: 2024])
  # end

end
