defmodule KjogviWeb.Live.Lifelist.ParamsTest do
  use Kjogvi.DataCase, async: true

  alias KjogviWeb.Live.Lifelist.Params
  alias Kjogvi.Birding.Lifelist.Filter

  test "no parameters" do
    result = Params.to_filter(%{user: nil}, %{})
    assert result == {:ok, Filter.discombo!([])}
  end

  test "unknown keys are discarded" do
    result = Params.to_filter(%{user: nil}, %{"a" => "b"})
    assert result == {:ok, Filter.discombo!([])}
  end

  test "only valid year" do
    result = Params.to_filter(%{user: nil}, %{"year_or_location" => "2024"})
    assert result == {:ok, Filter.discombo!(year: 2024)}
  end

  test "valid month parameter" do
    result = Params.to_filter(%{user: nil}, %{"month" => "6"})
    assert result == {:ok, Filter.discombo!(month: 6)}
  end

  test "invalid numeric month parameter" do
    result = Params.to_filter(%{user: nil}, %{"month" => "13"})
    assert {:error, _} = result
  end

  test "invalid string month parameter" do
    result = Params.to_filter(%{user: nil}, %{"month" => "abc"})
    assert {:error, _} = result
  end

  test "only public location" do
    ukraine = insert(:location, slug: "ukraine", name_en: "Ukraine", location_type: "country")
    result = Params.to_filter(%{user: nil}, %{"year_or_location" => "ukraine"})
    assert result == {:ok, Filter.discombo!(location: ukraine)}
  end

  test "private location unavailable for guest" do
    insert(:location,
      slug: "ukraine",
      name_en: "Ukraine",
      location_type: "country",
      is_private: true
    )

    result = Params.to_filter(%{user: nil}, %{"year_or_location" => "ukraine"})
    assert {:error, _} = result
  end

  test "private location unavailable in public view" do
    user = Kjogvi.UsersFixtures.user_fixture()

    insert(:location,
      slug: "ukraine",
      name_en: "Ukraine",
      location_type: "country",
      is_private: true
    )

    result =
      Params.to_filter(%{user: user, private_view: false}, %{"year_or_location" => "ukraine"})

    assert {:error, _} = result
  end

  test "private location available in private view for user" do
    user = Kjogvi.UsersFixtures.user_fixture()

    ukraine =
      insert(:location,
        slug: "ukraine",
        name_en: "Ukraine",
        location_type: "country",
        is_private: true
      )

    result =
      Params.to_filter(%{user: user, private_view: true}, %{"year_or_location" => "ukraine"})

    assert result == {:ok, Filter.discombo!(location: ukraine)}
  end
end
