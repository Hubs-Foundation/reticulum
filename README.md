# Reticulum

A hybrid game networking and web API server, focused on Social Mixed Reality.

## Development

Use `docker-compose` to setup a local environment. 

Change the database host name in the `Ret.Repo` from `"localhost"` to `"dev"` in `config/dev.exs`. You may also have to configure the `RetWeb.Endpoint` host. Then start the servers:

    $ docker-compose up
