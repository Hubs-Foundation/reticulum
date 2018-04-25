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
    core/elixir/1.5.1
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
    rm -rf priv/static
    mkdir -p priv/static

    mix local.hex --force
    mix local.rebar --force
    mix deps.get --only prod

    pushd assets
    mkdir -p .yarn
    mkdir -p node_modules

    # Yarn expects /usr/local/share
    # https://github.com/yarnpkg/yarn/issues/4628
    mkdir -p /usr/local/share

    yarn install --cache-folder .yarn
    yarn build

    rm -rf client
    git clone https://github.com/mozilla/hubs.git client

    pushd client
    yarn install --cache-folder ../.yarn
    GENERATE_SMOKE_TESTS=true BASE_ASSETS_PATH="https://assets-prod.reticulum.io/" yarn build -- --output-path ../../priv/static
    popd

    rm -rf client

    popd

    mix compile
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
