pkg_name=reticulum
pkg_origin=hubsfoundation
pkg_version="1.0.1"
pkg_maintainer="Hubs Foundation <info@hubsfoundation.org>"
pkg_upstream_url="http://github.com/Hubs-Foundation/reticulum"
pkg_license=('MPL-2.0')
pkg_deps=(
    core/coreutils/8.30/20190115012313
    core/bash/4.4.19/20190115012619
    core/which/2.21/20190430084037
)
pkg_build_deps=(
    core/coreutils/8.30/20190115012313
    core/git/2.23.0
    hubsfoundation/erlang/23.3.4.18
    hubsfoundation/elixir/1.14.3
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
    export RELEASE_VERSION="1.0.$(echo $pkg_prefix | cut -d '/' -f 7)"

    # Rebar3 will hate us otherwise because it looks for
    # /usr/bin/env when it does some of its compiling
    [[ ! -f /usr/bin/env ]] && ln -s "$(pkg_path_for coreutils)/bin/env" /usr/bin/env

    return 0
}
do_build() {
    mix local.hex --force
    mix local.rebar --force
    mix deps.get --only prod
    mix deps.clean mime --build
    rm -rf _build
    mix compile
}
do_install() {
    rm -rf _build/prod/rel/ret/releases
    MIX_ENV=prod mix release
    # TODO 1.9 releases chmod 0655 _build/prod/rel/ret/bin/*
    cp -a _build/prod/rel/ret/* ${pkg_prefix}

    for f in $(find ${pkg_prefix} -name '*.sh')
    do
        fix_interpreter "$f" core/bash bin/bash
        fix_interpreter "$f" core/coreutils bin/env
        # TODO 1.9 releases chmod 0655 "$f"
    done

    # TODO 1.9 releases chmod 0655 elixir, bin/erl
}
do_strip() {
    return 0
}
do_end() {
    return 0
}
