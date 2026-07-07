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
upgrade(){

load

if ! installed;then
echo "s-ui未安装"
return
fi

cd "$PATH_SUI"

if [ -f "$PATH_SUI/sui" ];then
./sui update
restart
echo "升级完成"
else
echo "未找到sui"
fi

}


admin(){

load

if ! installed;then
echo "s-ui未安装"
return
fi

read -p "管理员用户名:" u
read -s -p "管理员密码:" p
echo

cd "$PATH_SUI"

./sui admin -username "$u" -password "$p"

restart

echo "管理员修改完成"

}


change_port(){

load

read -p "新面板端口:" p

cd "$PATH_SUI"

./sui setting -port "$p"

PORT="$p"

save

restart

echo "端口修改完成"

}


change_sub(){

load

read -p "新订阅端口:" p

cd "$PATH_SUI"

./sui setting -subPort "$p"

SUBPORT="$p"

save

restart

echo "订阅端口修改完成"

}


change_path(){

load

read -p "新路径:" p

cd "$PATH_SUI"

./sui setting -path "$p"

PATH_SUI="$p"

save

echo "路径修改完成"

restart

}


status(){

load

echo "================"
echo "s-ui状态"
echo "================"

if installed;then
echo "安装状态: 已安装"
else
echo "安装状态: 未安装"
fi

echo "路径: $PATH_SUI"
echo "端口: $PORT"
echo "订阅端口: $SUBPORT"


if command -v systemctl >/dev/null;then

systemctl is-active s-ui >/dev/null 2>&1

if [ $? = 0 ];then
echo "服务: 运行中"
else
echo "服务: 未运行"
fi

elif command -v rc-service >/dev/null;then

rc-service s-ui status

else

echo "服务管理: 未检测"

fi

}


repo(){

load

read -p "GitHub用户名 [$REPO_USER]:" x
[ -n "$x" ]&&REPO_USER="$x"

read -p "仓库名 [$REPO_NAME]:" x
[ -n "$x" ]&&REPO_NAME="$x"

save

echo "仓库修改完成"

}


uninstall(){

load

echo "停止服务"

systemctl stop s-ui 2>/dev/null
rc-service s-ui stop 2>/dev/null


rm -rf "$PATH_SUI"

rm -f /etc/systemd/system/s-ui.service

rm -f /etc/init.d/s-ui

systemctl daemon-reload 2>/dev/null


echo "s-ui 已删除"

}


remove_script(){

rm -f "$INSTALL"
rm -f "$SHORT"
rm -f "$CONF"

hash -r

echo "管理脚本和suio已删除"

exit

}


menu(){

load

create_short

clear

echo "======================"
echo "     s-ui管理器 v3"
echo "======================"

if installed;then
echo "状态: 已安装"
else
echo "状态: 未安装"
fi

echo

echo "1. 安装s-ui"
echo "2. 卸载s-ui"
echo "3. 升级s-ui"
echo "4. 修改面板端口"
echo "5. 修改订阅端口"
echo "6. 修改管理员账号密码"
echo "7. 修改安装路径"
echo "8. 查看状态"
echo "9. 修改安装仓库"
echo "10. 删除脚本"
echo "0. 退出"

echo

read -p "选择:" n

case "$n" in

1) install ;;
2) uninstall ;;
3) upgrade ;;
4) change_port ;;
5) change_sub ;;
6) admin ;;
7) change_path ;;
8) status ;;
9) repo ;;
10) remove_script ;;
0) exit ;;
*) menu ;;

esac

}

menu
