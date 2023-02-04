defmodule Mix.Tasks.Ornitho.Import do
  @moduledoc """
  Runs a custom importer which imports a Book with Taxa. Provide the importer module as an
  argument. Optional parameter `--force` will remove the existing book and its taxa prior to
  importing.

  ## Examples

    $ mix ornitho.import Importer.Ebird.V1

  ## Command line options

  • `--force`, `-f` - force overwrite existing book and taxa
  """

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

        with {:ok, _} <- ensure_module_exists(importer),
             {:ok, _} <- ensure_function_exported(importer) do
          importer.process_import(force: force)
        else
          {:error, error} ->
            Mix.raise(error)
        end

      {_, _} ->
        Mix.raise(
          "expected ornitho.import to receive the importer module name, " <>
            "got: #{inspect(Enum.join(args, " "))}\n" <>
            "See 'mix help ornitho.import' for details."
        )
    end
  end

  defp ensure_module_exists(module) do
    case Code.ensure_compiled(module) do
      {:module, _} ->
        {:ok, module}

      {:error, error} ->
        {:error, "Could not load Importer module #{inspect(module)}, error: #{inspect(error)}."}
    end
  end

  defp ensure_function_exported(module) do
    if function_exported?(module, :process_import, 1) do
      {:ok, module}
    else
      {:error,
       "Module #{inspect(module)} is not an Importer, needs to define function 'process_import/1'."}
    end
  end
end
