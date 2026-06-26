# Kjógvi [^1]

## Run in development

1. Start the PostgreSQL database server:
   
   ```bash
   docker compose up -d
   ```

   Database runs on port 5498, see the `compose.yaml` file for credentials.

2. Install the dependencies:
   
   ```bash
   mix deps.get
   ```

3. If running for the first time, setup the database:

   ```bash
   mix ecto.setup
   ```

4. Start the server:

   ```bash
   iex -S mix phx.server
   ```

   Application will be available on http://localhost:4000.

5. If there are pending migrations, you will be prompted to run them.

6. To setup admin user, find the setup code in the logs.

### To run the tests:

1. Create the test DB:

   ```bash
   MIX_ENV=test mix ecto.setup
   ```

2. Run the tests:

   ```bash
   mix test
   ```

## Credits

* The bicycle icon is from [Font Awesome Free](https://fontawesome.com/) 6.x
(`solid/bicycle`), licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

* Country and subdivision geo data is derived from the
[iso-codes](https://salsa.debian.org/iso-codes-team/iso-codes) project
(ISO 3166 codes and names), licensed under LGPL-2.1-or-later.

[^1]: Pronounced [ˈtʃɛkvɪ].
