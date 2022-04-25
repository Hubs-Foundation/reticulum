# TODO: need a better one
healthcheck(){
    while true; do (echo -e 'HTTP/1.1 200 OK\r\n\r\n 1') | nc -lp 1111 > /dev/null; done
}

sed -i "s/{{POD_DNS}}/ret.${POD_NS}.svc.cluster.local/g" config.toml 
echo "update runtime configs into config.toml" 
prefix="turkeyCfg_"; for var in $(compgen -e); do [[ $var == $prefix* ]] && sed -i "s/{{${var#$prefix}}}/${!var//\//\\\/}/g" config.toml; done 
[ -f "config.toml.template" ] && mv config.toml.template config.toml && prefix="turkeyCfg_"; for var in $(compgen -e); do [[ $var == $prefix* ]] && sed -i "s/<${var#$prefix}>/${!var//\//\\\/}/g" config.toml; done 
export HOME="/ret/var" LC_ALL="en_US.UTF-8 LANG=en_US.UTF-8" REPLACE_OS_VARS="true" 
export MIX_ENV="turkey" RELEASE_CONFIG_DIR="/ret" RELEASE_MUTABLE_DIR="/ret/var" 
export NODE_NAME="${POD_IP}" NODE_COOKIE="foobar" 
echo "NODE_NAME=$NODE_NAME" 
healthcheck &
TURKEY_MODE=1 exec /ret/bin/ret foreground
