HUBS_OPS_SECRETS_PATH=${1:-"../hubs-ops-secrets"}
RET_DEV_VARS="roles/ret/vars/dev.yml"

PERMS_KEY="$(
  ansible-vault view "$HUBS_OPS_SECRETS_PATH/$RET_DEV_VARS" |
    grep guardian_perms_key |
    cut -d':' -f2 |
    sed 's/\\\\\\\\n/\\n/g' | # un-escape
    sed 's/^[ \t"]\+\|[ \t"]\+$//g' # trim
)"

if [ -z "$PERMS_KEY" ]; then
  >&2 echo "$(tput setaf 1)Perms key not found. Exiting.$(tput sgr0)"
  exit 1
else
  PERMS_KEY="$PERMS_KEY" mix phx.server
fi
