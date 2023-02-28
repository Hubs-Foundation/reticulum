# syntax=docker/dockerfile:1
ARG ALPINE_VERSION=3.16.2
ARG ELIXIR_VERSION=1.14.3
ARG ERLANG_VERSION=23.3.4.18

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${ERLANG_VERSION}-alpine-${ALPINE_VERSION} AS base
RUN mix do local.hex --force, local.rebar --force

FROM base AS dev
RUN apk add --no-cache\
    # required by hex\
    git\
    # required by hex:phoenix_live_reload\
    inotify-tools
COPY container/dev-perms.pem /etc/perms.pem
COPY container/trapped-mix /usr/local/bin/trapped-mix
WORKDIR /code
HEALTHCHECK CMD wget --no-check-certificate --no-verbose --tries=1 --spider https://localhost:4000/stream-offline.png
CMD sh -c "PERMS_KEY=\"$(cat /etc/perms.pem)\" mix phx.server"

FROM base AS builder
RUN apk add --no-cache nodejs yarn git build-base
COPY . .
RUN mix deps.get
RUN MIX_ENV=turkey mix release

FROM alpine/openssl AS certr
WORKDIR certs
RUN openssl req -x509 -newkey rsa:2048 -sha256 -days 36500 -nodes -keyout key.pem -out cert.pem -subj '/CN=ret' && cp cert.pem cacert.pem

FROM alpine:${ALPINE_VERSION}
RUN mkdir -p /storage && chmod 777 /storage
WORKDIR ret
COPY --from=builder /_build/turkey/rel/ret/ .
COPY --from=certr /certs .
RUN apk update && apk add --no-cache bash openssl-dev openssl jq libstdc++ coreutils
COPY container/prod-run.sh /run.sh
CMD bash /run.sh
