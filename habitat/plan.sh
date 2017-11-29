pkg_name=reticulum
pkg_origin=mozillareality
pkg_version="0.0.1"
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"
pkg_upstream_url="http://github.com/mozilla/reticulum"
pkg_license=('MPL-2.0')

pkg_deps=(
    core/coreutils
    core/bash
    core/which
    core/erlang/20.0
)

pkg_build_deps=(
    core/coreutils
    core/git
    idolgirev/yarn
    core/node
    core/erlang/20.0
    core/elixir/1.5.0
)

pkg_exports=(
   [port]=phx.port
)

pkg_description="A moral imperative."

do_verify() {
    return 0
}

do_prepare() {
    export LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
    export MIX_ENV=prod

    # Rebar3 will hate us otherwise because it looks for
    # /usr/bin/env when it does some of its compiling
    [[ ! -f /usr/bin/env ]] && ln -s "$(pkg_path_for coreutils)/bin/env" /usr/bin/env

    return 0
}

do_build() {
    mix local.hex --force
    mix local.rebar --force
    mix deps.get --only prod
    mix compile

    mkdir -p tmp/yarn-cache
    cd assets
    yarn --cache-folder ../tmp/yarn-cache install
    yarn --cache-folder ../tmp/yarn-cache upgrade mr-social-client
    ./node_modules/brunch/bin/brunch build -p
    npm explore mr-social-client -- yarn install --cache-folder ../tmp/yarn-cache
    npm explore mr-social-client -- npm run build
    rm -rf ../priv/static/client
    mkdir -p ../priv/static
    cp -rf node_modules/mr-social-client/public ../priv/static/client
    cd ..

    mix phx.digest
}

do_install() {
    mix release --env=prod
    cp -a _build/prod/rel/ret/* ${pkg_prefix}
    cp priv/bin/conform ${pkg_prefix}/bin

    for f in $(find ${pkg_prefix} -name '*.sh')
    do
        fix_interpreter "$f" core/bash bin/bash
        fix_interpreter "$f" core/coreutils bin/env
    done
}

do_strip() {
    return 0
}

do_end() {
    return 0
}
