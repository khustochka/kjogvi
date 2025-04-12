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

3. Start the server:

   ```bash
   iex -S mix phx.server
   ```

   Application will be available on http://localhost:4000.

4. When run first time, you will be prompted to run the migrations.

5. To setup admin user, find the setup code in the logs.

### To run the tests:

1. Create the test DB:

   ```bash
   MIX_ENV=test mix ecto.setup
   ```

2. Run the tests:

   ```bash
   mix test
   ```

[^1]: Pronounced [ˈtʃɛkvɪ].
