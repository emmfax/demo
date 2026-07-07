#!/bin/sh
# s-ui mini manager
# github: emmfax/demo

VER="1.0"
CONF="/etc/suio.conf"
BIN="/usr/local/bin/suio"
SCRIPT="/usr/local/bin/sui.sh"

[ "$(id -u)" != "0" ]&&echo "请使用root运行"&&exit 1

GREEN="\033[32m"
RED="\033[31m"
NC="\033[0m"

ok(){ echo "${GREEN}$1${NC}"; }
err(){ echo "${RED}$1${NC}"; }

load(){
[ -f "$CONF" ]&&. "$CONF"
REPO_USER=${REPO_USER:-alireza0}
REPO_NAME=${REPO_NAME:-s-ui}
PATH_SUI=${PATH_SUI:-/usr/local/s-ui}
PORT=${PORT:-2095}
USER=${USER:-admin}
PASS=${PASS:-admin}
}

save(){
cat >$CONF <<EOF
REPO_USER=$REPO_USER
REPO_NAME=$REPO_NAME
PATH_SUI=$PATH_SUI
PORT=$PORT
USER=$USER
PASS=$PASS
EOF
}

sui_exist(){
[ -d "$PATH_SUI" ]||[ -f "/etc/systemd/system/s-ui.service" ]||[ -f "/etc/init.d/s-ui" ]
}

dep(){
apk update >/dev/null 2>&1&&apk add curl wget tar unzip bash >/dev/null 2>&1
command -v apt >/dev/null&&apt update -y >/dev/null 2>&1&&apt install -y curl wget tar unzip bash >/dev/null 2>&1
}

service_start(){
if command -v systemctl >/dev/null;then
systemctl daemon-reload
systemctl enable s-ui >/dev/null 2>&1
systemctl restart s-ui
elif command -v rc-update >/dev/null;then
rc-update add s-ui default >/dev/null 2>&1
rc-service s-ui restart
fi
}

service_stop(){
systemctl stop s-ui 2>/dev/null
rc-service s-ui stop 2>/dev/null
}

install_sui(){
load
dep
mkdir -p "$PATH_SUI"

echo "当前仓库:"
echo "https://github.com/$REPO_USER/$REPO_NAME"
read -p "输入版本(留空最新版): " VERSION

if [ -z "$VERSION" ];then
URL="https://github.com/$REPO_USER/$REPO_NAME/releases/latest/download/s-ui-linux-amd64.tar.gz"
else
URL="https://github.com/$REPO_USER/$REPO_NAME/releases/download/$VERSION/s-ui-linux-amd64.tar.gz"
fi

echo "下载:"
wget -O /tmp/sui.tar.gz "$URL"

if [ $? != 0 ];then
err "下载失败"
exit 1
fi

tar zxvf /tmp/sui.tar.gz -C "$PATH_SUI"

chmod +x "$PATH_SUI"/*

echo
read -p "端口 [$PORT]: " x
[ -n "$x" ]&&PORT=$x

read -p "用户名 [$USER]: " x
[ -n "$x" ]&&USER=$x

read -p "密码 [$PASS]: " x
[ -n "$x" ]&&PASS=$x

read -p "安装路径 [$PATH_SUI]: " x
[ -n "$x" ]&&PATH_SUI=$x

save

create_service

service_start

create_cmd

ok "安装完成"
}

create_service(){

if command -v systemctl >/dev/null;then

cat >/etc/systemd/system/s-ui.service <<EOF
[Unit]
Description=s-ui
After=network.target

[Service]
Type=simple
WorkingDirectory=$PATH_SUI
ExecStart=$PATH_SUI/s-ui
Restart=always

[Install]
WantedBy=multi-user.target
EOF

else

cat >/etc/init.d/s-ui <<EOF
#!/sbin/openrc-run
command="$PATH_SUI/s-ui"
command_background=true
pidfile="/run/s-ui.pid"
EOF

chmod +x /etc/init.d/s-ui

fi
}

create_cmd(){
cat >$BIN <<EOF
#!/bin/sh
cd $PATH_SUI
echo "s-ui path:$PATH_SUI"
EOF
chmod +x $BIN
}

uninstall(){
load
service_stop
rm -rf "$PATH_SUI"
rm -f /etc/systemd/system/s-ui.service
rm -f /etc/init.d/s-ui
systemctl daemon-reload 2>/dev/null
rm -f $BIN
rm -f $CONF
ok "已卸载"
}

upgrade(){

load

echo "升级仓库:"
echo "$REPO_USER/$REPO_NAME"

install_sui

}

status(){
systemctl status s-ui --no-pager 2>/dev/null||rc-service s-ui status 2>/dev/null
}

change_port(){
load
read -p "新端口:" PORT
save
echo "请进入s-ui面板修改端口"
}

change_user(){
load
read -p "新用户名:" USER
save
echo "请进入s-ui面板修改"
}

change_pass(){
load
read -p "新密码:" PASS
save
echo "请进入s-ui面板修改"
}

change_path(){
load
read -p "新路径:" p
[ -n "$p" ]&&PATH_SUI=$p
save
echo "路径已保存，请手动迁移目录"
}

repo(){
load
read -p "GitHub用户名 [$REPO_USER]:" x
[ -n "$x" ]&&REPO_USER=$x

read -p "仓库名 [$REPO_NAME]:" x
[ -n "$x" ]&&REPO_NAME=$x

save
ok "仓库修改完成"
}

remove_script(){

rm -f $SCRIPT
rm -f $BIN
rm -f $CONF

ok "脚本清理完成"
exit
}

menu(){

load

clear

echo "======================"
echo "      s-ui 管理器"
echo "======================"

if sui_exist;then
echo "状态: 已安装"
else
echo "状态: 未安装"
fi

echo
echo "1.安装 s-ui"
echo "2.卸载 s-ui"
echo "3.升级 s-ui"
echo "4.修改端口"
echo "5.修改用户名"
echo "6.修改密码"
echo "7.修改路径"
echo "8.查看状态"
echo "9.修改安装仓库"
echo "10.删除脚本"
echo "0.退出"

read -p "选择:" n

case $n in
1)install_sui;;
2)uninstall;;
3)upgrade;;
4)change_port;;
5)change_user;;
6)change_pass;;
7)change_path;;
8)status;;
9)repo;;
10)remove_script;;
0)exit;;
*)menu;;
esac
}

menu
