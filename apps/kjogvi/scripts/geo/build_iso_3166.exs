# Generates the ISO 3166 JSONL source for `Kjogvi.Geo.Import` from Debian's
# iso-codes JSON files. The default output is the local datasets storage
# (`priv/datasets/geo/sources/iso_3166.jsonl`); for prod, upload the file to
# the datasets S3 bucket under the same key (the app only reads it).
#
# Source data: the iso-codes project
# (https://salsa.debian.org/iso-codes-team/iso-codes), licensed
# LGPL-2.1-or-later. The ISO 3166 codes and names are factual data; the
# generated iso_3166.jsonl is a transformed derivative of that compilation.
#
# Reads ISO 3166-1 (countries/territories) and ISO 3166-2 (subdivisions) and
# emits one JSON object per line, parents before children, so the importer can
# resolve ancestry in a single pass. Countries become `country` locations and
# the top-level subdivisions become `subdivision1` locations (the level directly
# below a country). Lower-level ISO 3166-2 entries — those with a `parent`
# (council areas, departments, …) — are NOT emitted; only the subdivisions that
# hang directly off the country are imported.
#
# Every top-level ISO 3166-2 entry is emitted, including those denoting a place
# that is also an ISO 3166-1 country (`FR-BL` / `BL`, `NL-AW` / `AW`, …). Such
# rows are resolved downstream via the locations changelog
# (`priv/datasets/geo/iso_locations_changelog.jsonl`), which disables the
# subdivision in favour of the country, rather than being dropped at build time.
#
# The iso-codes source directory is auto-detected (Linux system path or
# Homebrew prefix on macOS); pass it explicitly to override.
#
# Usage:
#   mix run apps/kjogvi/scripts/geo/build_iso_3166.exs \
#     [<iso-codes/json dir>] [<output path>]

defmodule BuildIso3166 do
  # Known locations of the iso-codes JSON, in priority order.
  @candidate_srcs [
    "/usr/share/iso-codes/json",
    "/usr/local/share/iso-codes/json",
    "/opt/homebrew/opt/iso-codes/share/iso-codes/json"
  ]

  # The local datasets storage (see `config :kjogvi, Kjogvi.Datasets`), under
  # the key `Kjogvi.Geo.Import.source_key/0`.
  @default_out Path.join(:code.priv_dir(:kjogvi), "datasets/geo/sources/iso_3166.jsonl")

  def default_out, do: @default_out

  @doc """
  Locates the iso-codes JSON directory for the current OS, or aborts with
  install instructions if the package is not installed.
  """
  def detect_src do
    candidates = @candidate_srcs ++ List.wrap(brew_src())

    case Enum.find(candidates, &File.exists?(Path.join(&1, "iso_3166-1.json"))) do
      nil -> abort_not_installed()
      dir -> dir
    end
  end

  # On macOS, ask Homebrew where iso-codes is (covers non-default prefixes).
  defp brew_src do
    with {:unix, :darwin} <- :os.type(),
         {path, 0} <- System.cmd("brew", ["--prefix", "iso-codes"], stderr_to_stdout: true) do
      Path.join(String.trim(path), "share/iso-codes/json")
    else
      _ -> nil
    end
  rescue
    ErlangError -> nil
  end

  defp abort_not_installed do
    install_hint =
      case :os.type() do
        {:unix, :darwin} -> "brew install iso-codes"
        {:unix, _} -> "apt-get install iso-codes  # or your distro's equivalent"
        _ -> "install the iso-codes package"
      end

    IO.puts(:stderr, """
    Could not find the iso-codes JSON data. Install the package:

        #{install_hint}

    Or pass the directory containing iso_3166-1.json explicitly:

        elixir #{Path.relative_to_cwd(__ENV__.file)} <iso-codes/json dir>
    """)

    System.halt(1)
  end

  def run(src_dir, out_path) do
    version = detect_version(src_dir)
    countries = read(Path.join(src_dir, "iso_3166-1.json"))["3166-1"]
    subdivisions = read(Path.join(src_dir, "iso_3166-2.json"))["3166-2"]

    country_lines =
      Enum.map(countries, fn c ->
        "country"
        |> base_row(String.upcase(c["alpha_2"]), c["name"], nil)
        |> Map.put(:official_name, c["official_name"])
        |> Map.put(:numeric, c["numeric"])
      end)

    subdivision_lines =
      subdivisions
      # Only the top-level subdivisions (directly under the country) are imported.
      # ISO 3166-2 entries with a `parent` are lower-level (council areas,
      # departments, …); they are skipped rather than flattened to subdivision1.
      |> Enum.reject(&Map.has_key?(&1, "parent"))
      |> Enum.map(fn s ->
        [parent_iso, _] = String.split(s["code"], "-", parts: 2)
        base_row("subdivision1", s["code"], s["name"], String.upcase(parent_iso))
      end)

    lines =
      (country_lines ++ subdivision_lines)
      |> Enum.map(&Map.put(&1, :iso_codes_version, version))

    File.write!(out_path, Enum.map_join(lines, "\n", &Jason.encode!/1) <> "\n")

    IO.puts(
      "Wrote #{length(lines)} rows " <>
        "(#{length(country_lines)} countries, #{length(subdivision_lines)} subdivisions) " <>
        "from iso-codes #{version} to #{out_path}"
    )
  end

  # Reads the version from the pkg-config file shipped with iso-codes.
  defp detect_version(src_dir) do
    pc = Path.join([src_dir, "..", "..", "pkgconfig", "iso-codes.pc"])

    with {:ok, contents} <- File.read(pc),
         [_, version] <- Regex.run(~r/^Version:\s*(.+)$/m, contents) do
      String.trim(version)
    else
      _ -> "unknown"
    end
  end

  defp base_row(type, iso_code, name, parent_iso) do
    %{
      type: type,
      iso_code: iso_code,
      name_en: name,
      parent_iso: parent_iso
    }
  end

  defp read(path) do
    path |> File.read!() |> Jason.decode!()
  end
end

{src_dir, out_path} =
  case System.argv() do
    [src, out] -> {src, out}
    [src] -> {src, BuildIso3166.default_out()}
    [] -> {BuildIso3166.detect_src(), BuildIso3166.default_out()}
  end

BuildIso3166.run(src_dir, out_path)
