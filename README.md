# Kjógvi [^1]

## Run via Docker (prod demo)

1. Build the image:
   
   ```bash
   docker compose build
   ```
2. Start the containers (web container will be failing on the first run):
   
   ```bash
   docker compose up
   ```
3. To create the databases (if they do not exist) and migrate:

   ```bash
   docker compose exec web bin/migrate
   ```

[^1]: Pronounced [ˈtʃɛkvɪ].
