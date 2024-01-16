# Ornithologue

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ornithologue` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ornithologue, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/ornithologue>.

## Setup in an application

1. Declare and configure an Ecto repository in your app. It can be your "main" repository, 
   `MyApp.Repo`, or it can be a separate repository, e.g. `MyApp.OrnithoRepo`. The following 
   steps use the latter approach for clarity.

2. Configure the repository to be used by Ornithologue:

    ```elixir
    config :ornithologue, repo: MyApp.OrnithoRepo
    ```

3. Create a migration file:

    ```bash
    mix ecto.gen.migration create_ornithologue_tables -r MyApp.OrnithoRepo
    ```

4. Add the following code to the migration file:

    ```elixir
    defmodule MyApp.OrnithoRepo.Migrations.CreateOrnithologueTables do
      use Ecto.Migration

      def up do
        Ornitho.Migrations.up(version: 1)
      end

      def down do
        Ornitho.Migrations.down(version: 1)
      end
    end
    ```

5. Migrate:

    ```bash
    mix ecto.migrate -r MyApp.OrnithoRepo
    ```
