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
3. `mix ecto.migrate`

### Start Reticulum
Run `mix phx.server`
