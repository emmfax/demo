#!/bin/sh
# S-UI Manager
# Debian / Alpine
# Low Memory Container Edition

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

CONF=/etc/s-ui-manager.conf
TMP=/tmp/s-ui-install
SERVICE=s-ui

[ -f "$CONF" ] && . "$CONF"

OWNER=${OWNER:-alireza0}
REPO=${REPO:-s-ui}
INSTALL_PATH=${INSTALL_PATH:-/usr/local/s-ui}

red(){ echo "\033[31m$1\033[0m"; }
green(){ echo "\033[32m$1\033[0m"; }
yellow(){ echo "\033[33m$1\033[0m"; }

[ "$(id -u)" = 0 ] || { red "请使用root运行"; exit 1; }

os_check(){
if [ -f /etc/alpine-release ];then
 OS=alpine
elif [ -f /etc/debian_version ];then
 OS=debian
else
 red "不支持系统"
 exit 1
fi
}

save_conf(){
cat >$CONF <<EOF
OWNER=$OWNER
REPO=$REPO
INSTALL_PATH=$INSTALL_PATH
EOF
}

installed(){
[ -f "$INSTALL_PATH/s-ui" ]
}

deps(){
if [ "$OS" = alpine ];then
 apk add --no-cache curl wget tar gzip unzip file ca-certificates openssl >/dev/null 2>&1
else
 apt-get update >/dev/null 2>&1
 DEBIAN_FRONTEND=noninteractive apt-get install -y curl wget tar gzip unzip file ca-certificates openssl >/dev/null 2>&1
fi
}

service_restart(){
if [ "$OS" = alpine ];then
 nohup rc-service s-ui restart >/dev/null 2>&1 &
else
 nohup systemctl restart s-ui >/dev/null 2>&1 &
fi
}

service_start(){
if [ "$OS" = alpine ];then
 rc-service s-ui start >/dev/null 2>&1
else
 systemctl start s-ui >/dev/null 2>&1
fi
}

create_service(){
if [ "$OS" = alpine ];then

cat >/etc/init.d/s-ui <<EOF
#!/sbin/openrc-run
command="$INSTALL_PATH/s-ui"
command_background=true
pidfile="/run/s-ui.pid"
depend(){ need net; }
EOF

chmod +x /etc/init.d/s-ui

else

cat >/etc/systemd/system/s-ui.service <<EOF
[Unit]
Description=S-UI
After=network.target

[Service]
WorkingDirectory=$INSTALL_PATH
ExecStart=$INSTALL_PATH/s-ui
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

fi
}

download(){
mkdir -p $TMP
rm -rf $TMP/*

case "$(uname -m)" in
x86_64) ARCH=amd64;;
aarch64|arm64) ARCH=arm64;;
armv7*) ARCH=arm;;
*) ARCH=$(uname -m);;
esac

echo "获取Release..."

JSON=$(curl -fsL https://api.github.com/repos/$OWNER/$REPO/releases/latest)

[ -n "$JSON" ] || { red "获取Release失败"; return 1; }

URL=$(echo "$JSON"|grep browser_download_url|grep -Ei "$ARCH|linux"|head -1|cut -d'"' -f4)

if [ -z "$URL" ];then
 yellow "无法自动匹配"
 echo "$JSON"|grep browser_download_url
 read -p "输入下载地址:" URL
fi

echo "下载:"
echo "$URL"

i=0
while [ $i -lt 3 ]
do
 curl -L --connect-timeout 15 --retry 2 -o $TMP/pkg "$URL" && break
 i=$((i+1))
 sleep 2
done

[ -s $TMP/pkg ] || { red "下载失败"; return 1; }

TYPE=$(file $TMP/pkg)

echo "$TYPE"|grep -qi gzip && mv $TMP/pkg $TMP/pkg.tar.gz
echo "$TYPE"|grep -qi zip && mv $TMP/pkg $TMP/pkg.zip

}

install_sui(){

deps
download || return

read -p "安装版本(回车默认):" VERSION
read -p "端口(默认2095):" PORT
PORT=${PORT:-2095}

read -p "用户名(默认admin):" USER
USER=${USER:-admin}

read -p "密码:" PASS

read -p "安装路径($INSTALL_PATH):" PATH2
[ -n "$PATH2" ] && INSTALL_PATH=$PATH2

mkdir -p "$INSTALL_PATH"

if [ -f $TMP/pkg.tar.gz ];then
 tar --no-same-owner --no-same-permissions -xzf $TMP/pkg.tar.gz -C "$INSTALL_PATH"
elif [ -f $TMP/pkg.zip ];then
 unzip -q $TMP/pkg.zip -d "$INSTALL_PATH"
fi

chmod +x "$INSTALL_PATH/s-ui"

cat >"$INSTALL_PATH/config.txt" <<EOF
PORT=$PORT
USER=$USER
PASS=$PASS
EOF

save_conf
create_service

read -p "是否开机启动(y/n):" BOOT

if [ "$BOOT" = y ];then
 if [ "$OS" = alpine ];then
  rc-update add s-ui default
 else
  systemctl enable s-ui
 fi
fi

service_start

rm -rf $TMP

green "安装完成"
}
upgrade(){
installed || { red "未安装"; return; }

download || return

if [ -f $TMP/pkg.tar.gz ];then
 tar --no-same-owner --no-same-permissions -xzf $TMP/pkg.tar.gz -C "$INSTALL_PATH"
elif [ -f $TMP/pkg.zip ];then
 unzip -oq $TMP/pkg.zip -d "$INSTALL_PATH"
fi

chmod +x "$INSTALL_PATH/s-ui"
service_restart
rm -rf $TMP
green "升级完成"
}

uninstall(){
read -p "确认卸载(y/n):" OK
[ "$OK" = y ] || return

if [ "$OS" = alpine ];then
 rc-service s-ui stop >/dev/null 2>&1
 rc-update del s-ui default >/dev/null 2>&1
 rm -f /etc/init.d/s-ui
else
 systemctl stop s-ui >/dev/null 2>&1
 systemctl disable s-ui >/dev/null 2>&1
 rm -f /etc/systemd/system/s-ui.service
 systemctl daemon-reload
fi

rm -rf "$INSTALL_PATH"
rm -f "$CONF"

green "卸载完成"
}

modify(){
FILE="$INSTALL_PATH/config.txt"
[ -f "$FILE" ] || { red "配置不存在"; return; }

case "$1" in
port)
 read -p "新端口:" V
 sed -i "s/^PORT=.*/PORT=$V/" $FILE
;;
user)
 read -p "新用户名:" V
 sed -i "s/^USER=.*/USER=$V/" $FILE
;;
pass)
 read -p "新密码:" V
 sed -i "s/^PASS=.*/PASS=$V/" $FILE
;;
esac

service_restart
green "修改完成"
}

change_path(){
read -p "新路径:" NEW
[ -n "$NEW" ] || return

mkdir -p "$NEW"
cp -a "$INSTALL_PATH"/* "$NEW"/

INSTALL_PATH="$NEW"
save_conf
create_service
service_restart

green "路径修改完成"
}

change_repo(){
echo "当前仓库:$OWNER/$REPO"

read -p "Github用户名:" O
read -p "仓库名:" R

[ -n "$O" ] && OWNER=$O
[ -n "$R" ] && REPO=$R

save_conf
green "仓库修改完成"
}

status(){

if installed;then
 green "S-UI 已安装"
 echo "路径:$INSTALL_PATH"
 echo "仓库:$OWNER/$REPO"

 if [ "$OS" = alpine ];then
  rc-service s-ui status
 else
  systemctl status s-ui --no-pager
 fi

else
 yellow "S-UI 未安装"
fi

}

show_config(){
echo "================"
echo "仓库:$OWNER/$REPO"
echo "路径:$INSTALL_PATH"

[ -f "$INSTALL_PATH/config.txt" ] && cat "$INSTALL_PATH/config.txt"

echo "================"
}


menu(){

while true
do

clear

echo "=============================="
echo "        S-UI 管理脚本"
echo "=============================="

if installed;then
 green "状态: 已安装"
else
 yellow "状态: 未安装"
fi

echo
echo "1. 安装 S-UI"
echo "2. 卸载 S-UI"
echo "3. 升级 S-UI"
echo "4. 修改端口"
echo "5. 修改用户名"
echo "6. 修改密码"
echo "7. 修改安装路径"
echo "8. 查看状态"
echo "9. 修改安装仓库"
echo "10. 查看配置"
echo "0. 退出"

echo
read -p "选择:" C

case $C in
1) install_sui;;
2) uninstall;;
3) upgrade;;
4) modify port;;
5) modify user;;
6) modify pass;;
7) change_path;;
8) status;;
9) change_repo;;
10) show_config;;
0) exit;;
*) echo "错误";;
esac

echo
read -p "回车继续..."

done

}


os_check
save_conf
menu
