defmodule Kjogvi.Users.User.ExtrasTest do
  use Kjogvi.DataCase, async: true

  alias Kjogvi.Users.User.Extras

  describe "changeset/2" do
    test "casts log_settings" do
      extras = %Extras{}

      changeset =
        Extras.changeset(extras, %{
          "log_settings" => %{
            "0" => %{"location_id" => "", "life" => "true", "year" => "false"},
            "1" => %{"location_id" => "42", "life" => "true", "year" => "true"}
          }
        })

      assert changeset.valid?
      settings = Ecto.Changeset.apply_changes(changeset).log_settings
      assert length(settings) == 2

      world = Enum.find(settings, &is_nil(&1.location_id))
      assert world.life == true
      assert world.year == false

      loc = Enum.find(settings, &(&1.location_id == 42))
      assert loc.life == true
      assert loc.year == true
    end

    test "preserves ebird when only log_settings are provided" do
      extras = %Extras{ebird: %Extras.Ebird{username: "testuser"}}

      changeset =
        Extras.changeset(extras, %{
          "log_settings" => %{
            "0" => %{"location_id" => "", "life" => "true", "year" => "true"}
          }
        })

      assert changeset.valid?
      result = Ecto.Changeset.apply_changes(changeset)
      assert result.ebird.username == "testuser"
    end
  end
end
