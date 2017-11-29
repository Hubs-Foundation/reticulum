#!/bin/bash

# To run tests + build, run:
# hab studio run "bash scripts/build.sh"

# On exit, need to make all files writable so CI can clean on next build
trap 'chmod -R a+rw .' EXIT

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

pushd "$DIR/.."

pkg_test_deps=(
  core/git
  core/postgresql
  core/hab-sup
)

export LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export MIX_ENV=prod

function join_by { local IFS="$1"; shift; echo "$*"; }

mkdir -p tmp

# Rebar3 will hate us otherwise because it looks for
# /usr/bin/env when it does some of its compiling
rm /usr/bin/env
ln -s "$(hab pkg path core/coreutils)/bin/env" /usr/bin/env

. habitat/plan.sh
deps="$(join_by " " "${pkg_deps[@]}") $(join_by " " "${pkg_build_deps[@]}") $(join_by " " "${pkg_test_deps[@]}")"


hab pkg install -b $deps
hab svc start core/postgresql &

MIX_ENV=test

mix do local.hex --force, local.rebar --force, deps.get, ecto.create, ecto.migrate

mix test > tmp/reticulum-test-$(date +%Y%m%d%H%M%S).log && build

test_pid=$!

hab svc stop core/postgresql
popd

exit $!
