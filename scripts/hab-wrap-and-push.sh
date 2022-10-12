
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

bio origin key generate mozillareality
habCacheKeyPath="/hab/cache/keys"
echo "habCacheKeyPath: $habCacheKeyPath"
mkdir -p $habCacheKeyPath
echo $BLDR_HAB_TOKEN > $habCacheKeyPath/mozillareality_hab
echo $BLDR_RET_TOKEN > $habCacheKeyPath/mozillareality_ret
export HAB_ORIGIN=mozillareality
export HAB_ORIGIN_KEYS=mozillareality_hab

echo "### build hab pkg"
export HAB_AUTH_TOKEN=$BLDR_HAB_TOKEN

mkdir -p /repo/ret
cp -r /ret/* /repo/ret/

cd /repo
cat > habitat/plan.sh << 'EOF'
pkg_name=reticulum
pkg_origin=mozillareality
pkg_version="1.0.1"
pkg_maintainer="Mozilla Mixed Reality <mixreality@mozilla.com>"
pkg_upstream_url="http://github.com/mozilla/reticulum"
pkg_license=('MPL-2.0')
pkg_deps=(
    core/coreutils/8.30/20190115012313
    core/bash/4.4.19/20190115012619
    core/which/2.21/20190430084037
    mozillareality/erlang/22.0
)
pkg_build_deps=(
    core/coreutils/8.30/20190115012313
    core/git/2.23.0
    mozillareality/erlang/22.0
    core/elixir/1.8.0
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
    MIX_ENV=prod mix distillery.release
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
bio pkg build --cache-key-path $habCacheKeyPath -k mozillareality .

### upload
echo "### upload hab pkg"
export HAB_BLDR_URL="https://bldr.reticulum.io"
export HAB_AUTH_TOKEN=$BLDR_RET_TOKEN
export HAB_ORIGIN_KEYS=mozillareality_ret
echo $BLDR_RET_PUB_B64 | base64 -d > /hab/cache/keys/mozillareality-20190117233449.pub
# cat /hab/cache/keys/mozillareality-20190117233449.pub
hart="/hab/cache/artifacts/$HAB_ORIGIN-reticulum*.hart"
ls -lha $hart
bio pkg upload $hart