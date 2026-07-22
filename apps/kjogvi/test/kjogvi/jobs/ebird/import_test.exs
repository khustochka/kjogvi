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

    test "unpacks the zip, imports the CSV, and cleans up the upload", %{dir: dir} do
      book = Ornitho.Factory.insert(:book)
      Ornitho.Factory.insert(:taxon, book: book, name_sci: "Anas platyrhynchos")

      user =
        Kjogvi.AccountsFixtures.user_fixture(
          default_book_signature: "#{book.slug}/#{book.version}"
        )

      header =
        "Submission ID,Common Name,Scientific Name,Taxonomic Order,Count," <>
          "State/Province,County,Location ID,Location,Latitude,Longitude,Date,Time," <>
          "Protocol,Duration (Min),All Obs Reported,Distance Traveled (km)," <>
          "Area Covered (ha),Number of Observers,Breeding Code,Observation Details," <>
          "Checklist Comments,ML Catalog Numbers"

      row =
        "S1,Mallard,Anas platyrhynchos,1,2,X,,L100,Pond,,,2015-11-14,," <>
          "eBird - Casual Observation,0,0,,,1,,,,"

      zip = csv_zip(header <> "\n" <> row <> "\n")
      {:ok, key} = Upload.store(user, :ebird, "zip", zip)

      # The region is unlinked, so the location can't be mapped and the checklist
      # is skipped — but the job runs, imports, and reports cleanly.
      assert {:ok, %{checklists_created: 0, checklists_unmapped: 1}} =
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

  describe "import log recording" do
    @moduletag :capture_log

    setup do
      book = Ornitho.Factory.insert(:book)
      Ornitho.Factory.insert(:taxon, book: book, name_sci: "Anas platyrhynchos")

      user =
        Kjogvi.AccountsFixtures.user_fixture(
          default_book_signature: "#{book.slug}/#{book.version}"
        )

      %{user: user}
    end

    test "a drained run finishes its import log with the summary", %{user: user} do
      header =
        "Submission ID,Common Name,Scientific Name,Taxonomic Order,Count," <>
          "State/Province,County,Location ID,Location,Latitude,Longitude,Date,Time," <>
          "Protocol,Duration (Min),All Obs Reported,Distance Traveled (km)," <>
          "Area Covered (ha),Number of Observers,Breeding Code,Observation Details," <>
          "Checklist Comments,ML Catalog Numbers"

      row =
        "S1,Mallard,Anas platyrhynchos,1,2,X,,L100,Pond,,,2015-11-14,," <>
          "eBird - Casual Observation,0,0,,,1,,,,"

      zip = csv_zip(header <> "\n" <> row <> "\n")
      {:ok, key} = Upload.store(user, :ebird, "zip", zip)

      {:ok, log} = Kjogvi.Imports.enqueue_ebird_import(user, key)
      Oban.drain_queue(queue: :imports)

      log = Kjogvi.Repo.get!(Kjogvi.Imports.ImportLog, log.id)
      # The unlinked region leaves the checklist unmapped — an errors outcome.
      assert log.status == :completed_with_errors
      assert log.summary["checklists_unmapped"] == 1
      assert log.started_at
      assert log.finished_at
    end

    test "a failed run marks its import log failed with the reason", %{user: user} do
      {:ok, {_name, zip}} =
        :zip.create(~c"export.zip", [{~c"readme.txt", "no csv here"}], [:memory])

      {:ok, key} = Upload.store(user, :ebird, "zip", zip)

      {:ok, log} = Kjogvi.Imports.enqueue_ebird_import(user, key)
      Oban.drain_queue(queue: :imports)

      log = Kjogvi.Repo.get!(Kjogvi.Imports.ImportLog, log.id)
      assert log.status == :failed
      assert log.error == ":no_csv_in_zip"
    end
  end
end
