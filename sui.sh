#!/bin/sh
# s-ui manager v3
# https://github.com/emmfax/demo

CONF="/etc/sui-manager.conf"
INSTALL="/usr/local/bin/sui.sh"
SHORT="/usr/local/bin/suio"

[ "$(id -u)" != "0" ]&&echo "请使用root运行"&&exit 1

SELF=$(readlink -f "$0" 2>/dev/null)

if [ "$SELF" != "$INSTALL" ]&&[ -f "$SELF" ];then
cp "$SELF" "$INSTALL"
chmod +x "$INSTALL"
fi

load(){
[ -f "$CONF" ]&&. "$CONF"

REPO_USER=${REPO_USER:-alireza0}
REPO_NAME=${REPO_NAME:-s-ui}
PATH_SUI=${PATH_SUI:-/usr/local/s-ui}
PORT=${PORT:-2095}
SUBPORT=${SUBPORT:-2096}
}

save(){
cat >"$CONF"<<EOF
REPO_USER=$REPO_USER
REPO_NAME=$REPO_NAME
PATH_SUI=$PATH_SUI
PORT=$PORT
SUBPORT=$SUBPORT
EOF
}

create_short(){
cat >"$SHORT"<<EOF
#!/bin/sh
$INSTALL
EOF
chmod +x "$SHORT"
hash -r 2>/dev/null
}

dep(){
if command -v apk >/dev/null;then
apk add --no-cache curl wget tar gzip >/dev/null 2>&1
fi

if command -v apt >/dev/null;then
apt update >/dev/null 2>&1
apt install -y curl wget tar gzip >/dev/null 2>&1
fi
}

installed(){
[ -x "$PATH_SUI/sui" ]
}

restart(){

if command -v systemctl >/dev/null;then
systemctl restart s-ui 2>/dev/null
fi

if command -v rc-service >/dev/null;then
rc-service s-ui restart 2>/dev/null
fi

}

enable(){

if command -v systemctl >/dev/null;then
systemctl enable s-ui >/dev/null 2>&1
fi

if command -v rc-update >/dev/null;then
rc-update add s-ui default >/dev/null 2>&1
fi

}

create_service(){

if command -v systemctl >/dev/null;then

cat >/etc/systemd/system/s-ui.service <<EOF
[Unit]
Description=s-ui
After=network.target

[Service]
WorkingDirectory=$PATH_SUI
ExecStart=$PATH_SUI/sui
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

else

cat >/etc/init.d/s-ui <<EOF
#!/sbin/openrc-run
command="$PATH_SUI/sui"
command_background=true
EOF

chmod +x /etc/init.d/s-ui

fi

}

install(){

load
dep

mkdir -p "$PATH_SUI"

echo "仓库:"
echo "https://github.com/$REPO_USER/$REPO_NAME"

read -p "版本(空为最新版): " V

if [ -z "$V" ];then
URL="https://github.com/$REPO_USER/$REPO_NAME/releases/latest/download/s-ui-linux-amd64.tar.gz"
else
URL="https://github.com/$REPO_USER/$REPO_NAME/releases/download/$V/s-ui-linux-amd64.tar.gz"
fi

wget -O /tmp/sui.tar.gz "$URL"||exit

tar zxvf /tmp/sui.tar.gz -C "$PATH_SUI"

chmod +x "$PATH_SUI/sui"

read -p "安装路径 [$PATH_SUI]: " x
[ -n "$x" ]&&PATH_SUI="$x"

read -p "面板端口 [$PORT]: " x
[ -n "$x" ]&&PORT="$x"

read -p "订阅端口 [$SUBPORT]: " x
[ -n "$x" ]&&SUBPORT="$x"

save

cd "$PATH_SUI"

./sui setting -port "$PORT"
./sui setting -subPort "$SUBPORT"

create_service
enable
restart
create_short

echo "安装完成"
}
