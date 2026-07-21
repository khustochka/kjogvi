defmodule Kjogvi.Jobs.Ebird.ImportTest do
  # Not async: swaps the Kjogvi.Imports.Upload application env.
  use Kjogvi.DataCase, async: false

  alias Kjogvi.Imports.Upload
  alias Kjogvi.Jobs.Ebird.Import

  setup do
    dir = Path.join(System.tmp_dir!(), "imports_job_#{System.unique_integer([:positive])}")
    original = Application.get_env(:kjogvi, Upload)

    Application.put_env(:kjogvi, Upload,
      adapter: Kjogvi.Imports.Upload.LocalAdapter,
      path: dir
    )

    on_exit(fn ->
      Application.put_env(:kjogvi, Upload, original)
      File.rm_rf(dir)
    end)

    %{dir: dir}
  end

  # A zip binary holding a single CSV entry, as eBird ships it.
  defp csv_zip(csv) do
    {:ok, {_name, bin}} =
      :zip.create(~c"export.zip", [{~c"MyEBirdData.csv", csv}], [:memory])

    bin
  end

  test "pubsub_key/1 maps the user id to the task key" do
    assert Import.pubsub_key(%Oban.Job{args: %{"user_id" => 7}}) == {:ebird_import, 7}
  end

  test "start_message/1 names the task" do
    assert Import.start_message(%Oban.Job{}) == "eBird import in progress..."
  end

  test "each user holds their own exclusive slot" do
    job1 = Oban.insert!(Import.new(%{user_id: 1, upload_key: "a"}))
    job2 = Oban.insert!(Import.new(%{user_id: 1, upload_key: "b"}))
    job3 = Oban.insert!(Import.new(%{user_id: 2, upload_key: "c"}))

    assert job2.conflict?
    assert job2.id == job1.id
    refute job3.conflict?
  end

  describe "perform/1" do
    setup do
      %{user: Kjogvi.AccountsFixtures.user_fixture()}
    end

    test "unpacks the zip, imports the CSV, and cleans up the upload", %{dir: dir, user: user} do
      zip = csv_zip("Row ID,Common Name\n1,Mallard\n2,Gadwall\n")
      {:ok, key} = Upload.store(user, :ebird, "zip", zip)

      assert {:ok, %{row_count: 2}} =
               Import.perform(%Oban.Job{args: %{"user_id" => user.id, "upload_key" => key}})

      # The single-use upload is deleted once consumed.
      refute File.exists?(Path.join(dir, key))
    end

    test "errors on a zip with no CSV, and still cleans up the upload", %{dir: dir, user: user} do
      {:ok, {_name, zip}} =
        :zip.create(~c"export.zip", [{~c"readme.txt", "no csv here"}], [:memory])

      {:ok, key} = Upload.store(user, :ebird, "zip", zip)

      assert {:error, :no_csv_in_zip} =
               Import.perform(%Oban.Job{args: %{"user_id" => user.id, "upload_key" => key}})

      refute File.exists?(Path.join(dir, key))
    end

    test "errors on a corrupt zip", %{user: user} do
      {:ok, key} = Upload.store(user, :ebird, "zip", "not a zip at all")

      assert {:error, {:bad_zip, _reason}} =
               Import.perform(%Oban.Job{args: %{"user_id" => user.id, "upload_key" => key}})
    end
  end
end
