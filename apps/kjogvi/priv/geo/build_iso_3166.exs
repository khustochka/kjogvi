# Generates priv/geo/iso_3166.jsonl from Debian's iso-codes JSON files.
#
# Source data: the iso-codes project
# (https://salsa.debian.org/iso-codes-team/iso-codes), licensed
# LGPL-2.1-or-later. The ISO 3166 codes and names are factual data; the
# generated iso_3166.jsonl is a transformed derivative of that compilation.
#
# Reads ISO 3166-1 (countries/territories) and ISO 3166-2 (subdivisions) and
# emits one JSON object per line, parents before children, so the importer can
# resolve ancestry in a single pass. Countries become `country` locations and
# subdivisions become `subdivision1` locations (the level directly below a
# country).
#
# Dual-entity rule (eBird-style): an ISO 3166-2 entry `XX-YY` denotes the same
# place as ISO 3166-1 code `YY` only when (1) `YY` is a valid alpha-2 code AND
# (2) the names match after normalization. Such entries are NOT emitted as
# subdivisions — the place is already present as a standalone country (`YY`).
#
# The iso-codes source directory is auto-detected (Linux system path or
# Homebrew prefix on macOS); pass it explicitly to override.
#
# Usage:
#   elixir apps/kjogvi/priv/geo/build_iso_3166.exs \
#     [<iso-codes/json dir>] [apps/kjogvi/priv/geo/iso_3166.jsonl]

Mix.install([{:jason, "~> 1.4"}])

defmodule BuildIso3166 do
  # Known locations of the iso-codes JSON, in priority order.
  @candidate_srcs [
    "/usr/share/iso-codes/json",
    "/usr/local/share/iso-codes/json",
    "/opt/homebrew/opt/iso-codes/share/iso-codes/json"
  ]

  @default_out Path.join(__DIR__, "iso_3166.jsonl")

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

    # alpha_2 (upcased) => normalized English name
    by_alpha_2 =
      Map.new(countries, fn c -> {String.upcase(c["alpha_2"]), normalize(c["name"])} end)

    country_lines =
      Enum.map(countries, fn c ->
        "country"
        |> base_row(String.upcase(c["alpha_2"]), c["name"], nil)
        |> Map.put(:official_name, c["official_name"])
        |> Map.put(:numeric, c["numeric"])
      end)

    subdivision_lines =
      subdivisions
      |> Enum.reject(&dual_entity?(&1, by_alpha_2))
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

  defp dual_entity?(%{"code" => code, "name" => name}, by_alpha_2) do
    case String.split(code, "-", parts: 2) do
      [_parent, sub] ->
        upper = String.upcase(sub)

        case Map.fetch(by_alpha_2, upper) do
          {:ok, country_name} -> normalize(name) == country_name
          :error -> false
        end

      _ ->
        false
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

  # Case-fold, strip diacritics, drop punctuation, trim a trailing "(the)".
  defp normalize(name) do
    name
    |> String.downcase()
    |> :unicode.characters_to_nfd_binary()
    |> String.replace(~r/[\x{0300}-\x{036f}]/u, "")
    |> String.replace(~r/\(the\)\s*$/u, "")
    |> String.replace(~r/[^\p{L}\p{N}]+/u, " ")
    |> String.trim()
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
