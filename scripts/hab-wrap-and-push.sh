
set -e

#BLDR_HAB_TOKEN='_Qk9YLTEKYmxkci0yMDE3M...'
#BLDR_RET_TOKEN='_Qk9YLTEKYmxkci0yMDE5M...'
#BLDR_RET_PUB_B64='U0lHLVBVQi0xCm1vemls...'

### preps
apk add curl
org="biome-sh";repo="biome"
ver=$(curl -s https://api.github.com/repos/$org/$repo/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3)}')
dl="https://github.com/$org/$repo/releases/download/$ver/bio-${ver#"v"}-x86_64-linux.tar.gz"
echo "[info] getting bio from: $dl" && curl -L -o bio.gz $dl && tar -xf bio.gz
cp ./bio /usr/bin/bio && bio --version

export HAB_ORIGIN=hubsfoundation

mkdir -p /hab/cache/keys/
mkdir -p ./hab/cache/keys/
echo $BLDR_RET_PUB_B64 | base64 -d > /hab/cache/keys/hubsfoundation-20190117233449.pub
echo $BLDR_RET_PUB_B64 | base64 -d > ./hab/cache/keys/hubsfoundation-20190117233449.pub
echo $BLDR_HAB_PVT_B64 | base64 -d > /hab/cache/keys/hubsfoundation-20190117233449.sig.key
echo $BLDR_HAB_PVT_B64 | base64 -d > /hab/cache/keys/hubsfoundation-20190117233449.sig.key

echo "### build hab pkg"
export HAB_AUTH_TOKEN=$BLDR_HAB_TOKEN

mkdir -p /repo/ret
cp -r /ret/* /repo/ret/

cd /repo
cat > habitat/plan.sh << 'EOF'
pkg_name=reticulum
pkg_origin=hubsfoundation
pkg_version="1.0.1"
pkg_maintainer="Hubs Foundation <info@hubsfoundation.org>"
pkg_upstream_url="http://github.com/Hubs-Foundation/reticulum"
pkg_license=('MPL-2.0')
pkg_deps=(
    core/coreutils/8.32/20220311101609
    core/bash/5.1/20220801055216
    core/which/2.21/20220311145823
    core/zlib/1.2.11/20220311082914
    core/openssl/1.0.2zb/20220311111046
)
pkg_build_deps=(
    core/coreutils/8.32/20220311101609
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
EOF
bio pkg build -k hubsfoundation .

### upload
echo "### upload hab pkg"
export HAB_BLDR_URL="https://bldr.reticulum.io"
export HAB_AUTH_TOKEN=$BLDR_RET_TOKEN
export HAB_ORIGIN_KEYS=hubsfoundation_ret
echo $BLDR_RET_PUB_B64 | base64 -d > /hab/cache/keys/hubsfoundation-20190117233449.pub
# cat /hab/cache/keys/hubsfoundation-20190117233449.pub
hart="/hab/cache/artifacts/$HAB_ORIGIN-reticulum*.hart"
ls -lha $hart
bio pkg upload $hart
