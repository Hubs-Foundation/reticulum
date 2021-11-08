FROM elixir:1.8-alpine as builder
RUN apk add --no-cache nodejs yarn git build-base
copy . .
RUN mix local.hex --force && mix local.rebar --force && mix deps.get
run mix deps.clean mime --build && rm -rf _build && mix compile
run MIX_ENV=turkey mix distillery.release
run cp ./rel/config.toml ./_build/turkey/rel/ret/config.toml

from alpine/openssl as certr
workdir certs
run openssl req -x509 -newkey rsa:2048 -sha256 -days 36500 -nodes -keyout key.pem -out cert.pem -subj '/CN=ret' && cp cert.pem cacert.pem

FROM alpine
run mkdir -p /storage && chmod 777 /storage
workdir ret
copy --from=builder /_build/turkey/rel/ret/ .
copy --from=certr /certs .
RUN apk update && apk add --no-cache bash openssl-dev openssl jq libstdc++
run printf 'while true; do (echo -e "HTTP/1.1 200 OK\r\n") | nc -lp 1111 > /dev/null; done' > /healthcheck.sh && chmod +x /healthcheck.sh
run printf ' \n\
sed -i "s/{{POD_DNS}}/ret.${POD_NS}.svc.cluster.local/g" config.toml \n\
echo "update runtime configs into config.toml" \n\
prefix="turkeyCfg_"; for var in $(compgen -e); do [[ $var == $prefix* ]] && sed -i "s/{{${var#$prefix}}}/${!var//\//\\\/}/g" config.toml; done \n\
export HOME="/ret/var" LC_ALL="en_US.UTF-8 LANG=en_US.UTF-8" REPLACE_OS_VARS="true" \n\
export MIX_ENV="turkey" RELEASE_CONFIG_DIR="/ret" RELEASE_MUTABLE_DIR="/ret/var" \n\
export NODE_NAME="${POD_IP}" NODE_COOKIE="foobar" \n\
echo "NODE_NAME=$NODE_NAME" \n\
/healthcheck.sh& \n\
TURKEY_MODE=1 exec /ret/bin/ret foreground ' > /run.sh
cmd bash /run.sh
