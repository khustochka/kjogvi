defmodule KjogviWeb.Live.Lifelist.ParamsTest do
  use Kjogvi.DataCase, async: true

  alias KjogviWeb.Live.Lifelist.Params
  alias Kjogvi.Birding.Lifelist.Filter

  test "no parameters" do
    opts = Params.to_filter(nil, %{})
    assert opts == Filter.discombo([])
  end

  test "unknown keys are discarded" do
    opts = Params.to_filter(nil, %{"a" => "b"})
    assert opts == Filter.discombo([])
  end

  test "only valid year" do
    opts = Params.to_filter(nil, %{"year_or_location" => "2024"})
    assert opts == Filter.discombo(year: 2024)
  end

  test "valid month parameter" do
    opts = Params.to_filter(nil, %{"month" => "6"})
    assert opts == Filter.discombo(month: 6)
  end

  test "invalid numeric month parameter" do
    assert_raise Plug.BadRequestError, fn ->
      Params.to_filter(nil, %{"month" => "13"})
    end
  end

  test "invalid string month parameter" do
    assert_raise Plug.BadRequestError, fn ->
      Params.to_filter(nil, %{"month" => "abc"})
    end
  end

  test "only public location" do
    ukraine = insert(:location, slug: "ukraine", name_en: "Ukraine", location_type: "country")
    opts = Params.to_filter(nil, %{"year_or_location" => "ukraine"})
    assert opts == Filter.discombo(location: ukraine)
  end

  test "private location unavailable for guest" do
    insert(:location,
      slug: "ukraine",
      name_en: "Ukraine",
      location_type: "country",
      is_private: true
    )

    assert_raise Ecto.NoResultsError, fn ->
      Params.to_filter(nil, %{"year_or_location" => "ukraine"})
    end
  end

  test "private location available for logged in user" do
    user = Kjogvi.UsersFixtures.user_fixture()

    ukraine =
      insert(:location,
        slug: "ukraine",
        name_en: "Ukraine",
        location_type: "country",
        is_private: true
      )

    opts = Params.to_filter(user, %{"year_or_location" => "ukraine"})
    assert opts == Filter.discombo(location: ukraine)
  end
end
