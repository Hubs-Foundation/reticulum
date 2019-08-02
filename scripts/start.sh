ENV_FILE=${1:-"../.ret-env"}
env "$(cat "$ENV_FILE" | tr '\n' ' ')" mix phx.server
