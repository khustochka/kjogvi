defmodule Mix.Tasks.Ornitho.Import do
  @moduledoc "The task to import a book"
  use Mix.Task

  @aliases [
    f: :force
  ]

  @switches [
    force: :boolean
  ]

  @shortdoc "The task to import a book."
  def run(args) do
    Mix.Task.run("app.start")

    case OptionParser.parse!(args, strict: @switches, aliases: @aliases) do
      {opts, [importer_name]} ->
        force = opts[:force]
        importer = Module.concat([importer_name])

        case Ornitho.Importer.process_import(importer, force: force) do
          {:error, :incorrect_importer_module} ->
            Mix.raise("Importer module #{Atom.to_string(importer)} does not exists")

          {:error, :overwrite_not_allowed} ->
            Mix.raise(
              "A book for importer #{Atom.to_string(importer)} already exists, " <>
                "to force overwrite it pass --force. All taxa will be deleted!"
            )

          {:ok, _} ->
            nil
        end

      {_, _} ->
        Mix.raise(
          "expected ornitho.import to receive the importer module name, " <>
            "got: #{inspect(Enum.join(args, " "))}"
        )
    end
  end
end
