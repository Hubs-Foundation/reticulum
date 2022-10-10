# TODO: need a better one
healthcheck(){
    while true; do (echo -e 'HTTP/1.1 200 OK\r\n\r\n 1') | nc -lp 1111 > /dev/null; done
}
if [ -f /home/ret/config.toml.template ]; then
    echo "[INFO] /home/ret/config.toml.template => config.toml" 
    cp /home/ret/config.toml.template config.toml
fi

prefix="turkeyCfg_"; for var in $(compgen -e); do [[ $var == $prefix* ]] && sed -i "s/<${var#$prefix}>/${!var//\//\\\/}/g" config.toml; done 
export HOME="/ret/var" LC_ALL="en_US.UTF-8 LANG=en_US.UTF-8" REPLACE_OS_VARS="true" 
export MIX_ENV="turkey" RELEASE_CONFIG_DIR="/ret" RELEASE_MUTABLE_DIR="/ret/var" 
export NODE_NAME="${POD_IP}" NODE_COOKIE="foobar" 
echo "NODE_NAME=$NODE_NAME" 
healthcheck &
# TURKEY_MODE=1 exec /ret/bin/ret foreground
python d2e.py > /ret/releases/1.0.0/runtime.exs
TURKEY_MODE=1 exec /ret/bin/ret start
