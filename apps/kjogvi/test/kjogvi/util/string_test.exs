defmodule Kjogvi.Util.StringTest do
  use ExUnit.Case, async: true

  alias Kjogvi.Util.String, as: US

  describe "strip_diacritics/1" do
    test "removes accents but keeps case and punctuation" do
      assert US.strip_diacritics("Rhône-Alpes") == "Rhone-Alpes"
      assert US.strip_diacritics("Århus County") == "Arhus County"
    end

    test "folds non-decomposing Latin letters, preserving case" do
      assert US.strip_diacritics("Łódź") == "Lodz"
      assert US.strip_diacritics("Øster") == "Oster"
      assert US.strip_diacritics("Þingvellir") == "THingvellir"
    end
  end

  describe "normalize_for_match/1" do
    test "strips diacritics, downcases, collapses punctuation and whitespace" do
      assert US.normalize_for_match("Rhône–Alpes") == "rhone alpes"
      assert US.normalize_for_match("Saint-Denis") == "saint denis"
      assert US.normalize_for_match("Co. Kerry") == "co kerry"
      assert US.normalize_for_match("  Århus   County ") == "arhus county"
      assert US.normalize_for_match("Baden-Württemberg") == "baden wurttemberg"
    end

    test "folds non-decomposing Latin letters to their base form" do
      # These do not decompose under NFD, so the diacritic strip alone leaves
      # them; eBird flattens them while ISO keeps them.
      assert US.normalize_for_match("Łódzkie") == "lodzkie"
      assert US.normalize_for_match("Malopolskie") == US.normalize_for_match("Małopolskie")
      assert US.normalize_for_match("Sør-Trøndelag") == "sor trondelag"
      assert US.normalize_for_match("Þingeyjarsýsla") == "thingeyjarsysla"
    end

    test "nil and empty names normalize to the empty string" do
      assert US.normalize_for_match(nil) == ""
      assert US.normalize_for_match("") == ""
      assert US.normalize_for_match(" - ") == ""
    end
  end
end
