# Reticulum

A hybrid game networking and web API server, focused on Social Mixed Reality.

## Development

Use `docker-compose` to setup a local environment. 

You may also have to configure the host and port in the [`RetWeb.Endpoint` section of `config/dev.exs`](https://github.com/mozilla/reticulum/blob/master/config/dev.exs#L10-L17). Then start the servers:

    $ DB_HOST=db docker-compose up


