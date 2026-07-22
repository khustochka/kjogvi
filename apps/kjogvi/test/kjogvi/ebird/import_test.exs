defmodule Kjogvi.Ebird.ImportTest do
  use Kjogvi.DataCase, async: true

  import Kjogvi.Factory

  alias Kjogvi.Birding.Checklist
  alias Kjogvi.Ebird.Import
  alias Kjogvi.Ebird.UserLocation
  alias Kjogvi.Geo.Location

  @header "Submission ID,Common Name,Scientific Name,Taxonomic Order,Count," <>
            "State/Province,County,Location ID,Location,Latitude,Longitude,Date,Time," <>
            "Protocol,Duration (Min),All Obs Reported,Distance Traveled (km)," <>
            "Area Covered (ha),Number of Observers,Breeding Code,Observation Details," <>
            "Checklist Comments,ML Catalog Numbers"

  # Writes a CSV holding @header plus the given data lines to a scratch file and
  # returns its path.
  defp csv_file(lines) do
    path = Path.join(System.tmp_dir!(), "ebird_#{System.unique_integer([:positive])}.csv")
    File.write!(path, Enum.join([@header | lines], "\n") <> "\n")
    on_exit(fn -> File.rm(path) end)
    path
  end

  # A user whose default book carries the given scientific names as taxa.
  defp user_with_taxa(name_scis) do
    book = Ornitho.Factory.insert(:book)

    for name_sci <- name_scis do
      Ornitho.Factory.insert(:taxon, book: book, name_sci: name_sci)
    end

    user =
      Kjogvi.AccountsFixtures.user_fixture(default_book_signature: "#{book.slug}/#{book.version}")

    {user, book}
  end

  defp row(fields) do
    Enum.join(fields, ",")
  end

  # The book's taxon key for a scientific name, as the import derives it.
  defp taxon_key(book, name_sci) do
    Ornitho.Finder.Taxon.all(book)
    |> Enum.find(&(&1.name_sci == name_sci))
    |> then(&Ornitho.Schema.Taxon.key(%{&1 | book: book}))
  end

  # A compact eBird CSV row at Texas location L100, taking the submission id,
  # scientific name, and count, plus optional overrides for other columns.
  defp tx_row(submission_id, name_sci, count, opts \\ []) do
    row([
      submission_id,
      Keyword.get(opts, :common_name, "Common"),
      name_sci,
      "243",
      count,
      "US-TX",
      "",
      Keyword.get(opts, :loc_id, "L100"),
      Keyword.get(opts, :loc_name, "Park"),
      "",
      "",
      Keyword.get(opts, :date, "2015-11-14"),
      "",
      Keyword.get(opts, :protocol, "eBird - Casual Observation"),
      "0",
      "0",
      "",
      "",
      "1",
      "",
      Keyword.get(opts, :notes, ""),
      "",
      ""
    ])
  end

  # Links the eBird `US-TX` region to a common subdivision1 so sites at Texas
  # locations get parented (and their checklists mapped).
  defp link_texas! do
    state = insert(:subdivision1, country: shared_country())
    insert(:ebird_subdivision1, code: "US-TX", country_code: "US", location: state)
    state
  end

  describe "run/3" do
    test "imports a checklist and its observations, resolving taxa by scientific name" do
      {user, _book} = user_with_taxa(["Dendrocygna autumnalis", "Anser caerulescens"])
      link_texas!()

      path =
        csv_file([
          row([
            "S1",
            "Black-bellied Whistling-Duck",
            "Dendrocygna autumnalis",
            "243",
            "5",
            "US-TX",
            "Bexar",
            "L100",
            "Brackenridge Park",
            "29.46",
            "-98.46",
            "2015-11-14",
            "01:00 PM",
            "eBird - Traveling Count",
            "160",
            "1",
            "5.5",
            "",
            "1",
            "",
            "",
            "",
            ""
          ]),
          row([
            "S1",
            "Snow Goose",
            "Anser caerulescens",
            "267",
            "X",
            "US-TX",
            "Bexar",
            "L100",
            "Brackenridge Park",
            "29.46",
            "-98.46",
            "2015-11-14",
            "01:00 PM",
            "eBird - Traveling Count",
            "160",
            "1",
            "5.5",
            "",
            "1",
            "",
            "",
            "",
            ""
          ])
        ])

      assert {:ok, summary} = Import.run(user, path)
      assert summary.checklists_created == 1
      assert summary.observations_created == 2
      assert summary.unresolved_taxa == []

      checklist =
        Checklist
        |> Repo.get_by(ebird_id: "S1")
        |> Repo.preload(:observations)

      assert checklist.user_id == user.id
      assert checklist.observ_date == ~D[2015-11-14]
      assert checklist.effort_type == "TRAVEL"
      assert checklist.import_source == :ebird
      assert length(checklist.observations) == 2
      assert Enum.all?(checklist.observations, &(&1.import_source == :ebird))
    end

    test "promotes imported taxa so each observed species gets a page" do
      {user, book} = user_with_taxa(["Dendrocygna autumnalis"])
      link_texas!()

      key =
        Ornitho.Finder.Taxon.all(book)
        |> Enum.find(&(&1.name_sci == "Dendrocygna autumnalis"))
        |> then(&Ornitho.Schema.Taxon.key(%{&1 | book: book}))

      refute Kjogvi.Pages.Species.from_taxon_key(key)

      path =
        csv_file([
          row([
            "S1",
            "BBWD",
            "Dendrocygna autumnalis",
            "243",
            "1",
            "US-TX",
            "",
            "L100",
            "Park",
            "",
            "",
            "2015-11-14",
            "",
            "eBird - Casual Observation",
            "0",
            "0",
            "",
            "",
            "1",
            "",
            "",
            "",
            ""
          ])
        ])

      assert {:ok, _summary} = Import.run(user, path)
      assert Kjogvi.Pages.Species.from_taxon_key(key)
    end

    test "unresolved scientific names are skipped and reported; the checklist still imports" do
      {user, _book} = user_with_taxa(["Dendrocygna autumnalis"])
      link_texas!()

      path =
        csv_file([
          row([
            "S1",
            "BBWD",
            "Dendrocygna autumnalis",
            "243",
            "1",
            "US-TX",
            "",
            "L100",
            "Park",
            "",
            "",
            "2015-11-14",
            "",
            "eBird - Casual Observation",
            "0",
            "0",
            "",
            "",
            "1",
            "",
            "",
            "",
            ""
          ]),
          row([
            "S1",
            "Unknown Sp",
            "Bogus specius",
            "999",
            "1",
            "US-TX",
            "",
            "L100",
            "Park",
            "",
            "",
            "2015-11-14",
            "",
            "eBird - Casual Observation",
            "0",
            "0",
            "",
            "",
            "1",
            "",
            "",
            "",
            ""
          ])
        ])

      assert {:ok, summary} = Import.run(user, path)
      assert summary.checklists_created == 1
      assert summary.observations_created == 1
      assert summary.unresolved_taxa == ["Bogus specius"]
    end

    test "creates a user location and a linked :site under the state's common location" do
      {user, _book} = user_with_taxa(["Dendrocygna autumnalis"])

      # The state's eBird region, linked to a common subdivision1.
      state = insert(:subdivision1, country: shared_country())
      insert(:ebird_subdivision1, code: "US-TX", country_code: "US", location: state)

      path =
        csv_file([
          row([
            "S1",
            "BBWD",
            "Dendrocygna autumnalis",
            "243",
            "1",
            "US-TX",
            "Bexar",
            "L956160",
            "Brackenridge Park",
            "29.46",
            "-98.46",
            "2015-11-14",
            "",
            "eBird - Casual Observation",
            "0",
            "0",
            "",
            "",
            "1",
            "",
            "",
            "",
            ""
          ])
        ])

      assert {:ok, _summary} = Import.run(user, path)

      user_location = Repo.get_by(UserLocation, user_id: user.id, ebird_loc_id: "L956160")
      assert user_location.name == "Brackenridge Park"
      assert user_location.state == "US-TX"
      assert user_location.county == "Bexar"

      site = Repo.get(Location, user_location.location_id)
      assert site.location_type == :site
      assert site.user_id == user.id
      assert site.slug == "l956160"
      assert site.subdivision1_id == state.id
      assert site.country_id == state.country_id
    end

    test "resolves an existing unmapped user location and imports its checklist" do
      {user, _book} = user_with_taxa(["Dendrocygna autumnalis"])
      state = link_texas!()

      # A user location left unmapped by an earlier run (its region wasn't matched
      # then). The state is matched now, so this run should link it and import.
      insert(:ebird_user_location,
        user: user,
        ebird_loc_id: "L956160",
        name: "Brackenridge Park",
        state: "US-TX",
        location: nil
      )

      path =
        csv_file([
          row([
            "S1",
            "BBWD",
            "Dendrocygna autumnalis",
            "243",
            "1",
            "US-TX",
            "Bexar",
            "L956160",
            "Brackenridge Park",
            "29.46",
            "-98.46",
            "2015-11-14",
            "",
            "eBird - Casual Observation",
            "0",
            "0",
            "",
            "",
            "1",
            "",
            "",
            "",
            ""
          ])
        ])

      assert {:ok, summary} = Import.run(user, path)
      assert summary.checklists_created == 1
      assert summary.checklists_unmapped == 0

      user_location = Repo.get_by(UserLocation, user_id: user.id, ebird_loc_id: "L956160")
      site = Repo.get(Location, user_location.location_id)
      assert site.location_type == :site
      assert site.subdivision1_id == state.id
      assert Repo.exists?(from(c in Checklist, where: c.ebird_id == "S1"))
    end

    test "leaves the location unmapped when only its country is linked, not the state" do
      {user, _book} = user_with_taxa(["Dendrocygna autumnalis"])

      # Only the country is linked; the state (US-TX) is not — no ancestor fallback,
      # so the site isn't created under the country.
      country = insert(:country)
      insert(:ebird_location, code: "US", country_code: "US", location: country)

      path =
        csv_file([
          row([
            "S1",
            "BBWD",
            "Dendrocygna autumnalis",
            "243",
            "1",
            "US-TX",
            "",
            "L777000",
            "Somewhere in Texas",
            "",
            "",
            "2015-11-14",
            "",
            "eBird - Casual Observation",
            "0",
            "0",
            "",
            "",
            "1",
            "",
            "",
            "",
            ""
          ])
        ])

      assert {:ok, summary} = Import.run(user, path)
      assert summary.checklists_created == 0
      assert summary.checklists_unmapped == 1

      user_location = Repo.get_by(UserLocation, user_id: user.id, ebird_loc_id: "L777000")
      assert user_location.location_id == nil
      refute Repo.exists?(from(c in Checklist, where: c.ebird_id == "S1"))
    end

    test "an unresolvable region leaves the location unmapped and skips its checklists" do
      {user, _book} = user_with_taxa(["Dendrocygna autumnalis"])

      path =
        csv_file([
          row([
            "S1",
            "BBWD",
            "Dendrocygna autumnalis",
            "243",
            "1",
            "X",
            "",
            "L777000",
            "Beausejour Area",
            "50.07",
            "-96.59",
            "2016-10-09",
            "",
            "eBird - Casual Observation",
            "0",
            "0",
            "",
            "",
            "1",
            "",
            "",
            "",
            ""
          ])
        ])

      assert {:ok, summary} = Import.run(user, path)
      assert summary.checklists_created == 0
      assert summary.checklists_unmapped == 1

      user_location = Repo.get_by(UserLocation, user_id: user.id, ebird_loc_id: "L777000")
      assert user_location.location_id == nil
      refute Repo.exists?(from(c in Checklist, where: c.ebird_id == "S1"))
    end

    test "a row with a blank Submission ID is counted invalid and imports nothing" do
      {user, _book} = user_with_taxa(["Dendrocygna autumnalis"])
      link_texas!()

      path =
        csv_file([
          row([
            "",
            "BBWD",
            "Dendrocygna autumnalis",
            "243",
            "1",
            "US-TX",
            "Bexar",
            "L100",
            "Brackenridge Park",
            "29.46",
            "-98.46",
            "2015-11-14",
            "01:00 PM",
            "eBird - Traveling Count",
            "160",
            "1",
            "5.5",
            "",
            "1",
            "",
            "",
            "",
            ""
          ])
        ])

      assert {:ok, summary} = Import.run(user, path)
      assert summary.checklists_invalid == 1
      assert summary.checklists_created == 0
      refute Repo.exists?(Checklist)
    end

    test "re-importing identical data leaves the checklist unchanged" do
      {user, _book} = user_with_taxa(["Dendrocygna autumnalis"])
      link_texas!()

      line = tx_row("S1", "Dendrocygna autumnalis", "1")

      assert {:ok, first} = Import.run(user, csv_file([line]))
      assert first.checklists_created == 1

      before = Repo.get_by!(Checklist, ebird_id: "S1")

      assert {:ok, second} = Import.run(user, csv_file([line]))
      assert second.checklists_created == 0
      assert second.checklists_updated == 0
      assert second.checklists_skipped == 1

      assert Repo.aggregate(from(c in Checklist, where: c.ebird_id == "S1"), :count) == 1
      # An unchanged checklist isn't rewritten.
      assert Repo.get_by!(Checklist, ebird_id: "S1").updated_at == before.updated_at
    end

    test "re-importing updates a changed checklist's fields in place" do
      {user, _book} = user_with_taxa(["Dendrocygna autumnalis"])
      link_texas!()

      assert {:ok, _} =
               Import.run(user, csv_file([tx_row("S1", "Dendrocygna autumnalis", "1")]))

      # eBird now reports a different count for the same observation.
      assert {:ok, summary} =
               Import.run(user, csv_file([tx_row("S1", "Dendrocygna autumnalis", "5")]))

      assert summary.checklists_created == 0
      assert summary.checklists_updated == 1

      checklist = Checklist |> Repo.get_by!(ebird_id: "S1") |> Repo.preload(:observations)
      assert [%{quantity: "5"}] = checklist.observations
      assert Repo.aggregate(from(c in Checklist, where: c.ebird_id == "S1"), :count) == 1
    end

    test "re-importing adds a newly reported observation, matching by taxon key" do
      {user, _book} = user_with_taxa(["Dendrocygna autumnalis", "Anser caerulescens"])
      link_texas!()

      assert {:ok, _} =
               Import.run(user, csv_file([tx_row("S1", "Dendrocygna autumnalis", "1")]))

      assert {:ok, summary} =
               Import.run(
                 user,
                 csv_file([
                   tx_row("S1", "Dendrocygna autumnalis", "1"),
                   tx_row("S1", "Anser caerulescens", "2")
                 ])
               )

      assert summary.checklists_updated == 1

      checklist = Checklist |> Repo.get_by!(ebird_id: "S1") |> Repo.preload(:observations)
      assert length(checklist.observations) == 2

      names = Enum.map(checklist.observations, & &1.taxon_key) |> Enum.uniq() |> length()
      assert names == 2
    end

    test "re-importing never deletes an observation dropped from the export" do
      {user, book} = user_with_taxa(["Dendrocygna autumnalis", "Anser caerulescens"])
      link_texas!()

      goose_key = taxon_key(book, "Anser caerulescens")

      assert {:ok, _} =
               Import.run(
                 user,
                 csv_file([
                   tx_row("S1", "Dendrocygna autumnalis", "1"),
                   tx_row("S1", "Anser caerulescens", "2")
                 ])
               )

      # The second species is gone from the re-export; it must survive with its data.
      assert {:ok, _} =
               Import.run(user, csv_file([tx_row("S1", "Dendrocygna autumnalis", "1")]))

      checklist = Checklist |> Repo.get_by!(ebird_id: "S1") |> Repo.preload(:observations)
      assert length(checklist.observations) == 2

      goose = Enum.find(checklist.observations, &(&1.taxon_key == goose_key))
      assert goose.quantity == "2"
    end

    test "re-importing backfills an observation whose taxon the book now carries" do
      # The book knows only the duck at first, so the goose row is dropped as an
      # unresolved taxon while its checklist still imports.
      {user, book} = user_with_taxa(["Dendrocygna autumnalis"])
      link_texas!()

      lines = [
        tx_row("S1", "Dendrocygna autumnalis", "1"),
        tx_row("S1", "Anser caerulescens", "2")
      ]

      assert {:ok, first} = Import.run(user, csv_file(lines))
      assert first.checklists_created == 1
      assert first.unresolved_taxa == ["Anser caerulescens"]

      checklist = Checklist |> Repo.get_by!(ebird_id: "S1") |> Repo.preload(:observations)
      assert length(checklist.observations) == 1

      # The goose is added to the book; a re-import backfills its observation.
      Ornitho.Factory.insert(:taxon, book: book, name_sci: "Anser caerulescens")

      assert {:ok, second} = Import.run(user, csv_file(lines))
      assert second.checklists_updated == 1
      assert second.unresolved_taxa == []

      checklist = Checklist |> Repo.get_by!(ebird_id: "S1") |> Repo.preload(:observations)
      assert length(checklist.observations) == 2
    end

    test "errors when the user has no default book" do
      user = Kjogvi.AccountsFixtures.user_fixture(default_book_signature: nil)
      path = csv_file([])

      assert {:error, :no_default_book} = Import.run(user, path)
    end
  end

  describe "error records" do
    alias Kjogvi.Imports

    defp import_log(user) do
      {:ok, log} =
        %{source: :ebird, user_id: user.id}
        |> Kjogvi.Imports.ImportLog.create_changeset()
        |> Repo.insert()

      log
    end

    # A full CSV line with everything but the varying fields defaulted.
    defp obs_row(submission_id, name_sci, state, loc_id) do
      row([
        submission_id,
        "Common Name",
        name_sci,
        "243",
        "1",
        state,
        "",
        loc_id,
        "Somewhere",
        "",
        "",
        "2015-11-14",
        "",
        "eBird - Casual Observation",
        "0",
        "0",
        "",
        "",
        "1",
        "",
        "",
        "",
        ""
      ])
    end

    test "an unmapped submission's raw rows are recorded" do
      {user, _book} = user_with_taxa(["Dendrocygna autumnalis"])
      log = import_log(user)

      path = csv_file([obs_row("S1", "Dendrocygna autumnalis", "X", "L1")])

      assert {:ok, summary} = Import.run(user, path, import_log_id: log.id)
      assert summary.errors_truncated == false

      assert [error] = Imports.list_import_errors(log.id)
      assert error.category == :unmapped
      assert error.submission_id == "S1"

      assert [%{"Submission ID" => "S1", "Scientific Name" => "Dendrocygna autumnalis"}] =
               error.rows
    end

    test "a submission with a blank Submission ID is recorded as invalid" do
      {user, _book} = user_with_taxa(["Dendrocygna autumnalis"])
      link_texas!()
      log = import_log(user)

      path = csv_file([obs_row("", "Dendrocygna autumnalis", "US-TX", "L100")])

      assert {:ok, _summary} = Import.run(user, path, import_log_id: log.id)

      assert [error] = Imports.list_import_errors(log.id)
      assert error.category == :invalid
      assert error.submission_id == nil
      assert [%{"Location ID" => "L100"}] = error.rows
    end

    test "rows dropped for unresolved taxa are recorded for an imported checklist" do
      {user, _book} = user_with_taxa(["Dendrocygna autumnalis"])
      link_texas!()
      log = import_log(user)

      path =
        csv_file([
          obs_row("S1", "Dendrocygna autumnalis", "US-TX", "L100"),
          obs_row("S1", "Bogus specius", "US-TX", "L100")
        ])

      assert {:ok, summary} = Import.run(user, path, import_log_id: log.id)
      assert summary.checklists_created == 1
      assert summary.observations_created == 1

      assert [error] = Imports.list_import_errors(log.id)
      assert error.category == :unresolved_taxa
      assert error.submission_id == "S1"
      assert [%{"Scientific Name" => "Bogus specius"}] = error.rows
    end

    test "records are capped per run and the summary flags truncation" do
      {user, _book} = user_with_taxa(["Dendrocygna autumnalis"])
      log = import_log(user)

      path =
        csv_file([
          obs_row("S1", "Dendrocygna autumnalis", "X", "L1"),
          obs_row("S2", "Dendrocygna autumnalis", "X", "L1")
        ])

      assert {:ok, summary} =
               Import.run(user, path, import_log_id: log.id, max_error_records: 1)

      assert summary.checklists_unmapped == 2
      assert summary.errors_truncated == true

      assert [%{category: :unmapped}] = Imports.list_import_errors(log.id)
    end

    test "without an import log the failures are only counted" do
      {user, _book} = user_with_taxa(["Dendrocygna autumnalis"])

      path = csv_file([obs_row("S1", "Dendrocygna autumnalis", "X", "L1")])

      assert {:ok, %{checklists_unmapped: 1}} = Import.run(user, path)
      assert Repo.aggregate(Kjogvi.Imports.ImportError, :count) == 0
    end
  end

  describe "errors?/1" do
    defp summary(overrides) do
      Map.merge(
        %{
          checklists_created: 5,
          observations_created: 20,
          checklists_skipped: 2,
          checklists_unmapped: 0,
          checklists_invalid: 0,
          checklists_failed: 0,
          unresolved_taxa: []
        },
        overrides
      )
    end

    test "a clean run has no errors, even with skipped duplicates" do
      refute Import.errors?(summary(%{}))
    end

    test "unmapped, invalid, or failed checklists are errors" do
      assert Import.errors?(summary(%{checklists_unmapped: 1}))
      assert Import.errors?(summary(%{checklists_invalid: 1}))
      assert Import.errors?(summary(%{checklists_failed: 1}))
    end

    test "unresolved taxa are errors" do
      assert Import.errors?(summary(%{unresolved_taxa: ["Bogus specius"]}))
    end
  end
end
