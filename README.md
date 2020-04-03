# Reticulum

A hybrid game networking and web API server, focused on Social Mixed Reality.

## Development

### Install Prerequisite Packages:
#### PostgreSQL (recommended version 11.x):
Linux: Use your package manager

Windows: https://www.postgresql.org/download/windows/

Windows WSL: https://github.com/michaeltreat/Windows-Subsystem-For-Linux-Setup-Guide/blob/master/readmes/installs/PostgreSQL.md

#### Elixr + Phoenix
https://elixir-lang.org/install.html
https://hexdocs.pm/phoenix/installation.html

### Setup Reticulum:
Run the following commands at the root of the reticulum directory:
1. `mix deps.get`
2. `mix ecto.create`
    * If step 2 fails, you may need to change the password for the `postgres` role to match the password configured `dev.exs`.
    * From within the `psql` shell, enter `ALTER USER postgres WITH PASSWORD 'postgres';`
3. from the `assets` directory, `npm install`
4. From the project directory `mkdir -p storage/dev`

### Start Reticulum
Run `scripts/run.sh` if you have the hubs secret repo cloned. Otherwise `iex -S mix phx.server`

## Run Hubs Against a Local Reticulum Instance
1. Clone and start hubs by running `./scripts/run_local_reticulum.sh` in the root of the hubs project
2. Go to https://hubs.local:4000?somerandomvar (note the random query string)
3. To sign in click the sign in link and submit your email.
4. Go to the reticulum terminal session and find a url that looks like https://hubs.local:4000/?auth_origin=hubs&auth_payload=XXXXX&auth_token=XXXX
5. Navigate to that url in your browser to finish signing in.

Adter you've started Reticulum for the first time you'll likely want to create an admin user. Assuming you want to make the first account the admin, this can be done in the iex console using the following code:

```
Ret.Account |> Ret.Repo.all() |> Enum.at(0) |> Ecto.Changeset.change(is_admin: true) |> Ret.Repo.update!()
```

## Run Spoke Against a Local Reticulum Instance
1. Follow the steps above to setup Hubs
2. Clone and start spoke by running `./scripts/run_local_reticulum.sh` in the root of the spoke project
3. Navigate to https://hubs.local:4000/spoke
 
