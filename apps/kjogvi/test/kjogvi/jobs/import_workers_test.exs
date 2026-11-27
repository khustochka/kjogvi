defmodule Kjogvi.Jobs.ImportWorkersTest do
  use Kjogvi.DataCase, async: true

  alias Kjogvi.Jobs.LegacyImport

  test "pubsub_key/1 maps the user id to the task keys" do
    assert LegacyImport.pubsub_key(%Oban.Job{args: %{"user_id" => 7}}) == {:legacy_import, 7}
  end

  test "start_message/1 names the task" do
    assert LegacyImport.start_message(%Oban.Job{}) == "Legacy import in progress..."
  end

  test "each user holds their own exclusive slot per task" do
    job1 = Oban.insert!(LegacyImport.new(%{user_id: 1}))
    job2 = Oban.insert!(LegacyImport.new(%{user_id: 1}))
    job3 = Oban.insert!(LegacyImport.new(%{user_id: 2}))

    assert job2.conflict?
    assert job2.id == job1.id
    refute job3.conflict?
  end

  describe "LegacyImport.perform/1" do
    test "surfaces the import's own error" do
      # The legacy taxonomy isn't loaded in the test DB, so the import refuses to run.
      user = Kjogvi.AccountsFixtures.user_fixture()

      assert {:error, %{message: message}} =
               LegacyImport.perform(%Oban.Job{args: %{"user_id" => user.id}})

      assert message =~ Kjogvi.Legacy.Import.book_signature()
    end
  end
end
