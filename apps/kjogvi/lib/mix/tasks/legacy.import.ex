defmodule Mix.Tasks.Legacy.Import do
  @moduledoc """
  Import legacy records.
  """

  use Mix.Task

  @aliases [
    u: :user
  ]

  @switches [
    user: :string
  ]

  @requirements ["app.start"]

  def run(args) do
    case OptionParser.parse!(args, strict: @switches, aliases: @aliases) do
      {opts, _} ->
        email = opts[:user]

        if email do
          user = Kjogvi.Users.get_user_by_email(email)

          Mix.Task.run("legacy.import.prepare")
          Mix.Task.run("legacy.import.locations")
          Mix.Task.run("legacy.import.cards", user: user)
          Mix.Task.run("legacy.import.observations")
        else
          Mix.raise("--user option is required")
        end
    end
  end
end
