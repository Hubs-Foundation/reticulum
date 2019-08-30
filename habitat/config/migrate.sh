#!{{ pkgPathFor "core/bash" }}/bin/bash

# Not a config, but a script that can be used to migrate the database. (A bit hacky since this lands in the config dir.)

set -e
exec 2>&1

export HOME={{ pkg.svc_var_path }}
export LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export REPLACE_OS_VARS=true # Inlines OS vars into vm args
export MIX_ENV=prod

export RELEASE_CONFIG_DIR={{ pkg.svc_config_path }}
export RELEASE_MUTABLE_DIR={{ pkg.svc_var_path }}

export NODE_NAME=$(echo $HOSTNAME | sed 's/\([^.]*\)\(.*\)$/\1{{ cfg.run.hostname_dns_suffix }}\2/')
export NODE_COOKIE={{ cfg.erlang.node_cookie }}

exec {{ pkg.path }}/bin/ret rpc 'Elixir.Ret.ReleaseTasks.migrate'
