#!/bin/sh
# s-ui manager v5
# fixed /usr/local/s-ui

BASE="/usr/local/s-ui"
SUI="$BASE/sui"
SCRIPT="$BASE/one.sh"
SHORT="/usr/local/bin/suio"
CONF="/etc/s-ui-manager.conf"

[ "$(id -u)" != "0" ]&&echo "请使用root运行"&&exit 1

load(){
[ -f "$CONF" ]&&. "$CONF"
REPO_USER=${REPO_USER:-alireza0}
REPO_NAME=${REPO_NAME:-s-ui}
PORT=${PORT:-2095}
SUBPORT=${SUBPORT:-2096}
}

save(){
cat >"$CONF"<<EOF
REPO_USER=$REPO_USER
REPO_NAME=$REPO_NAME
PORT=$PORT
SUBPORT=$SUBPORT
EOF
}

create_suio(){
mkdir -p /usr/local/bin
cat >/usr/local/bin/suio <<EOF
#!/bin/sh
/usr/local/s-ui/one.sh
EOF
chmod +x /usr/local/bin/suio
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
[ -x "$SUI" ]
}

service_create(){

if command -v systemctl >/dev/null;then

cat >/etc/systemd/system/s-ui.service <<EOF
[Unit]
Description=s-ui
After=network.target

[Service]
WorkingDirectory=/usr/local/s-ui
ExecStart=/usr/local/s-ui/sui
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

else

cat >/etc/init.d/s-ui <<EOF
#!/sbin/openrc-run

name="s-ui"
command="/usr/local/s-ui/sui"
command_background=true
pidfile="/run/s-ui.pid"

EOF

chmod +x /etc/init.d/s-ui

fi

}

service_enable(){

if command -v systemctl >/dev/null;then
systemctl enable s-ui >/dev/null 2>&1
fi

if command -v rc-update >/dev/null;then
rc-update add s-ui default >/dev/null 2>&1
fi

}

service_start(){

if command -v systemctl >/dev/null;then
systemctl start s-ui
fi

if command -v rc-service >/dev/null;then
rc-service s-ui start
fi

}

service_stop(){

if command -v systemctl >/dev/null;then
systemctl stop s-ui
fi

if command -v rc-service >/dev/null;then
rc-service s-ui stop
fi

}

service_restart(){

if command -v systemctl >/dev/null;then
systemctl restart s-ui
fi

if command -v rc-service >/dev/null;then
rc-service s-ui restart
fi

}


install_sui(){

load
dep

mkdir -p "$BASE"

echo "仓库:"
echo "https://github.com/$REPO_USER/$REPO_NAME"

read -p "版本(空=最新版): " VER


if [ -z "$VER" ];then
URL="https://github.com/$REPO_USER/$REPO_NAME/releases/latest/download/s-ui-linux-amd64.tar.gz"
else
URL="https://github.com/$REPO_USER/$REPO_NAME/releases/download/$VER/s-ui-linux-amd64.tar.gz"
fi


wget -O /tmp/s-ui.tar.gz "$URL" || exit 1


rm -rf "$BASE"/*


tar zxvf /tmp/s-ui.tar.gz -C "$BASE"


# 处理release一级目录
if [ -d "$BASE/s-ui" ];then
mv "$BASE/s-ui"/* "$BASE"/
rm -rf "$BASE/s-ui"
fi


# 自动寻找sui
if [ ! -f "$SUI" ];then
FOUND=$(find "$BASE" -name sui -type f 2>/dev/null|head -1)
if [ -n "$FOUND" ];then
mv "$FOUND" "$SUI"
fi
fi


chmod +x "$SUI"


if [ ! -f "$SUI" ];then
echo "错误:未找到sui程序"
exit 1
fi


echo
echo "开始初始化"


read -p "面板端口 [$PORT]: " x
[ -n "$x" ]&&PORT="$x"


read -p "订阅端口 [$SUBPORT]: " x
[ -n "$x" ]&&SUBPORT="$x"


read -p "管理员用户名:" USER


read -s -p "管理员密码:" PASS
echo


cd "$BASE"


./sui setting -path "$BASE"

./sui setting -port "$PORT"

./sui setting -subPort "$SUBPORT"

./sui admin -username "$USER" -password "$PASS"


save


service_create
service_enable
service_start


create_suio


echo
echo "================"
echo "s-ui安装完成"
echo "目录:$BASE"
echo "端口:$PORT"
echo "订阅:$SUBPORT"
echo "快捷命令:suio"
echo "================"

}
start_sui(){
if ! installed;then
echo "s-ui未安装"
return
fi
service_start
echo "s-ui启动完成"
}

stop_sui(){
service_stop
echo "s-ui停止完成"
}

upgrade_sui(){
load
if ! installed;then
echo "s-ui未安装"
return
fi

cd "$BASE"

if [ -f "$SUI" ];then
./sui update
service_restart
echo "升级完成"
else
echo "未找到sui"
fi
}

change_port(){
load

if ! installed;then
echo "s-ui未安装"
return
fi

read -p "新的面板端口:" p

cd "$BASE"

./sui setting -port "$p"

PORT="$p"
save

service_restart

echo "端口修改完成"
}

change_subport(){

load

if ! installed;then
echo "s-ui未安装"
return
fi

read -p "新的订阅端口:" p

cd "$BASE"

./sui setting -subPort "$p"

SUBPORT="$p"
save

service_restart

echo "订阅端口修改完成"
}


change_admin(){

if ! installed;then
echo "s-ui未安装"
return
fi

read -p "管理员用户名:" u

read -s -p "管理员密码:" p
echo

cd "$BASE"

./sui admin -username "$u" -password "$p"

service_restart

echo "管理员修改完成"
}


status_sui(){

load

echo "================"
echo "s-ui状态"
echo "================"

if installed;then
echo "安装状态: 已安装"
else
echo "安装状态: 未安装"
fi

echo "程序路径:$SUI"
echo "目录:$BASE"
echo "面板端口:$PORT"
echo "订阅端口:$SUBPORT"

echo

if command -v systemctl >/dev/null;then

systemctl status s-ui --no-pager

elif command -v rc-service >/dev/null;then

rc-service s-ui status

else

echo "未检测到服务管理器"

fi

}


log_sui(){

if command -v journalctl >/dev/null;then

journalctl -u s-ui -n 50 --no-pager

elif [ -f /var/log/s-ui.log ];then

tail -50 /var/log/s-ui.log

else

echo "没有找到日志"

fi

}


change_repo(){

load

read -p "GitHub用户名 [$REPO_USER]:" x

[ -n "$x" ]&&REPO_USER="$x"


read -p "GitHub仓库 [$REPO_NAME]:" x

[ -n "$x" ]&&REPO_NAME="$x"


save

echo "仓库修改完成"

}


uninstall_sui(){

service_stop

rm -rf "$BASE"

rm -f /etc/systemd/system/s-ui.service

rm -f /etc/init.d/s-ui

systemctl daemon-reload 2>/dev/null

echo "s-ui已卸载"

}


delete_script(){

rm -f "$SHORT"

rm -f "$CONF"

echo "suio和配置已删除"

exit

}


menu(){

load

create_suio

clear

echo "======================"
echo "       s-ui管理器 v5"
echo "======================"

if installed;then
echo "状态: 已安装"
else
echo "状态: 未安装"
fi

echo

echo "1. 启动 s-ui"
echo "2. 停止 s-ui"
echo "3. 安装 s-ui"
echo "4. 卸载 s-ui"
echo "5. 升级 s-ui"
echo "6. 修改面板端口"
echo "7. 修改订阅端口"
echo "8. 修改管理员账号密码"
echo "9. 查看状态"
echo "10. 修改安装仓库"
echo "11. 查看日志"
echo "12. 删除脚本"

echo
echo "0. 退出"

echo

read -p "选择:" n


case "$n" in

1) start_sui ;;
2) stop_sui ;;
3) install_sui ;;
4) uninstall_sui ;;
5) upgrade_sui ;;
6) change_port ;;
7) change_subport ;;
8) change_admin ;;
9) status_sui ;;
10) change_repo ;;
11) log_sui ;;
12) delete_script ;;
0) exit ;;
*) menu ;;

esac

}


menu
