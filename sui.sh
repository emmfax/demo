#!/bin/sh
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BASE="/usr/local"
CONF="/etc/sui.conf"
TMP="/tmp/sui_install"
[ -f "$CONF" ] && . "$CONF"

OWNER=${OWNER:-alireza0}
REPO=${REPO:-s-ui}
DIR=${DIR:-/usr/local/s-ui}
PORT=${PORT:-2095}
USER=${USER:-admin}
PASS=${PASS:-admin}

red(){ echo "\033[31m$1\033[0m"; }
green(){ echo "\033[32m$1\033[0m"; }

save(){
cat >$CONF <<EOF
OWNER=$OWNER
REPO=$REPO
DIR=$DIR
PORT=$PORT
USER=$USER
PASS=$PASS
EOF
}

detect(){
if [ -f "$DIR/s-ui" ] || command -v s-ui >/dev/null 2>&1;then
echo "已安装"
return 0
else
echo "未安装"
return 1
fi
}

dep(){
if command -v apk >/dev/null;then
apk add --no-cache curl wget tar gzip ca-certificates unzip
elif command -v apt >/dev/null;then
apt update -y
DEBIAN_FRONTEND=noninteractive apt install -y curl wget tar gzip ca-certificates unzip
fi
}

arch(){
case "$(uname -m)" in
x86_64) echo amd64;;
aarch64) echo arm64;;
armv7*) echo armv7;;
arm*) echo arm;;
*) echo amd64;;
esac
}

latest(){
curl -fsSL "https://api.github.com/repos/$OWNER/$REPO/releases/latest" | grep '"tag_name"'|head -1|cut -d '"' -f4
}

download(){
rm -rf "$TMP"
mkdir -p "$TMP"
A=$(arch)
TAG=$(latest)
[ -z "$TAG" ]&&exit 1

URL=$(curl -fsSL "https://api.github.com/repos/$OWNER/$REPO/releases/tags/$TAG" \
|grep browser_download_url \
|grep "$A" \
|head -1 \
|cut -d '"' -f4)

[ -z "$URL" ]&&{
red "没有找到匹配架构"
exit 1
}

wget -q --show-progress "$URL" -O "$TMP/sui.tar.gz"

}

install_sui(){

echo "开始后台安装保护SSH"
nohup sh -c '
dep
download

mkdir -p "$DIR"

tar -xzf "$TMP/sui.tar.gz" -C "$DIR" --no-same-owner

chmod +x "$DIR/s-ui" 2>/dev/null

cat >/etc/systemd/system/s-ui.service <<EOF
[Unit]
Description=s-ui
After=network.target

[Service]
Type=simple
WorkingDirectory=$DIR
ExecStart=$DIR/s-ui
Restart=always

[Install]
WantedBy=multi-user.target
EOF

if command -v systemctl >/dev/null;then
systemctl daemon-reload
systemctl enable s-ui
fi

if command -v rc-update >/dev/null;then
rc-update add s-ui default 2>/dev/null
fi

rm -rf "$TMP"

' >/tmp/sui_install.log 2>&1 &

green "安装任务已后台运行"
echo "日志:"
echo "tail -f /tmp/sui_install.log"

}

config(){

echo "安装路径 [$DIR]"
read -r x
[ -n "$x" ]&&DIR=$x

echo "端口 [$PORT]"
read -r x
[ -n "$x" ]&&PORT=$x

echo "用户名 [$USER]"
read -r x
[ -n "$x" ]&&USER=$x

echo "密码 [$PASS]"
read -r x
[ -n "$x" ]&&PASS=$x

save

}

uninstall(){
systemctl stop s-ui 2>/dev/null
systemctl disable s-ui 2>/dev/null
rc-service s-ui stop 2>/dev/null
rm -rf "$DIR"
rm -f /etc/systemd/system/s-ui.service
rm -f "$CONF"
green "已卸载"
}

upgrade(){

echo "升级后台执行"
nohup sh -c '
download
mkdir -p "$DIR/backup"
cp "$DIR/s-ui" "$DIR/backup/" 2>/dev/null
tar -xzf "$TMP/sui.tar.gz" -C "$DIR" --no-same-owner
chmod +x "$DIR/s-ui"
systemctl restart s-ui 2>/dev/null
rm -rf "$TMP"
' >/tmp/sui_upgrade.log 2>&1 &

echo "tail -f /tmp/sui_upgrade.log"

}

modify(){

case $1 in
port)
read -p "新端口:" PORT;;
user)
read -p "新用户名:" USER;;
pass)
read -p "新密码:" PASS;;
path)
read -p "新路径:" DIR;;
repo)
read -p "Github用户名:" OWNER
read -p "Github仓库:" REPO;;
esac

save
green "修改完成"
}

status(){

if detect;then
systemctl status s-ui --no-pager 2>/dev/null || ps |grep s-ui
else
echo "未安装"
fi

}

menu(){

while true
do
clear
echo "================="
echo " S-UI 管理脚本"
echo "================="
echo "状态:"
detect
echo
echo "1 安装"
echo "2 卸载"
echo "3 升级"
echo "4 修改端口"
echo "5 修改用户名"
echo "6 修改密码"
echo "7 修改路径"
echo "8 查看状态"
echo "9 修改安装仓库"
echo "0 退出"

read -p "选择:" n

case $n in
1)
dep
config
install_sui
;;
2) uninstall;;
3) upgrade;;
4) modify port;;
5) modify user;;
6) modify pass;;
7) modify path;;
8) status;;
9) modify repo;;
0) exit;;
esac

read -p "回车继续"
done
}

save
menu
