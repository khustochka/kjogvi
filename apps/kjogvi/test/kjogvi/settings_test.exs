defmodule Kjogvi.SettingsTest do
  use Kjogvi.DataCase, async: true

  alias Kjogvi.Settings

  describe "default_taxonomy/0" do
    test "derives the signature from the configured default importer" do
      assert Settings.default_taxonomy() == "ebird/v2025"
    end

    test "a database row overrides the config-derived signature" do
      {:ok, _} = Settings.put_setting(:default_taxonomy, "ebird/v2026")

      assert Settings.default_taxonomy() == "ebird/v2026"
    end

    test "an explicit nil row suppresses the config fallback" do
      {:ok, _} = Settings.put_setting(:default_taxonomy, nil)

      assert Settings.default_taxonomy() == nil
    end
  end

  describe "boolean flags" do
    test "default to the hardcoded value when neither row nor config is set" do
      refute Settings.registration_disabled?()
      refute Settings.forgot_reset_password_disabled?()
      refute Settings.email_confirmation_disabled?()
    end

    test "a database row overrides the default" do
      {:ok, _} = Settings.put_setting(:registration_disabled, true)

      assert Settings.registration_disabled?()
    end
  end

  describe "the setting roster" do
    test "flag_keys/0 lists the boolean kill switches" do
      assert Settings.flag_keys() == [
               :registration_disabled,
               :forgot_reset_password_disabled,
               :email_confirmation_disabled
             ]
    end

    test "keys/0 includes the non-flag settings too" do
      assert :default_taxonomy in Settings.keys()
    end

    test "key!/1 casts a known key and rejects an unknown one" do
      assert Settings.key!("registration_disabled") == :registration_disabled

      assert_raise ArgumentError, fn -> Settings.key!("sudo_mode") end
    end

    test "label/1 returns the positive feature name behind a flag" do
      assert Settings.label(:registration_disabled) == "Registration"
      assert Settings.label(:forgot_reset_password_disabled) == "Password reset"
      assert Settings.label(:email_confirmation_disabled) == "Email confirmation"
      assert Settings.label(:default_taxonomy) == "Default taxonomy"
    end

    test "fetch/1 resolves any setting by key" do
      refute Settings.fetch(:registration_disabled)

      {:ok, _} = Settings.put_setting(:registration_disabled, true)

      assert Settings.fetch(:registration_disabled)
    end
  end

  describe "get_override/1" do
    test "returns :error when no row exists" do
      assert Settings.get_override(:default_taxonomy) == :error
    end

    test "returns the stored value, including an explicit nil" do
      {:ok, _} = Settings.put_setting(:default_taxonomy, "ebird/v2026")
      assert Settings.get_override(:default_taxonomy) == {:ok, "ebird/v2026"}

      {:ok, _} = Settings.put_setting(:default_taxonomy, nil)
      assert Settings.get_override(:default_taxonomy) == {:ok, nil}
    end
  end

  describe "delete_setting/1" do
    test "removes the override, restoring the config fallback" do
      {:ok, _} = Settings.put_setting(:default_taxonomy, "ebird/v2026")
      assert Settings.default_taxonomy() == "ebird/v2026"

      :ok = Settings.delete_setting(:default_taxonomy)

      assert Settings.get_override(:default_taxonomy) == :error
      assert Settings.default_taxonomy() == "ebird/v2025"
    end

    test "is a no-op when no row exists" do
      assert Settings.delete_setting(:default_taxonomy) == :ok
    end
  end

  describe "put_setting/2" do
    test "upserts by key" do
      {:ok, first} = Settings.put_setting(:registration_disabled, true)
      {:ok, _} = Settings.put_setting(:registration_disabled, false)

      assert Repo.aggregate(Settings.Setting, :count) == 1
      assert Repo.get!(Settings.Setting, first.id).value == false
    end

    test "rejects an unknown key" do
      assert_raise NimbleOptions.ValidationError, fn ->
        Settings.put_setting(:sudo_mode, true)
      end
    end

    test "rejects a value of the wrong type" do
      assert_raise NimbleOptions.ValidationError, fn ->
        Settings.put_setting(:registration_disabled, "yes")
      end
    end

    test "round-trips string values" do
      {:ok, _} = Settings.put_setting(:default_taxonomy, "aba/v8")

      assert Repo.get_by!(Settings.Setting, key: "default_taxonomy").value == "aba/v8"
    end
  end
end
