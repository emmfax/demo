#!/bin/sh
# s-ui manager v4
# fixed path edition

BASE="/usr/local/s-ui"
BIN="$BASE/sui"
SCRIPT="/usr/local/sui.sh"
SHORT="/usr/local/suio"
CONF="/etc/sui-manager.conf"

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

create_short(){

cat >"$SHORT"<<EOF
#!/bin/sh
$SCRIPT
EOF

chmod +x "$SHORT"
hash -r 2>/dev/null

}

install_dep(){

if command -v apk >/dev/null;then
apk add --no-cache curl wget tar gzip >/dev/null 2>&1
fi

if command -v apt >/dev/null;then
apt update >/dev/null 2>&1
apt install -y curl wget tar gzip >/dev/null 2>&1
fi

}

installed(){

[ -x "$BIN" ]

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

elif command -v rc-update >/dev/null;then

rc-update add s-ui default >/dev/null 2>&1

fi

}


service_start(){

if command -v systemctl >/dev/null;then

systemctl start s-ui

elif command -v rc-service >/dev/null;then

rc-service s-ui start

fi

}


service_stop(){

if command -v systemctl >/dev/null;then

systemctl stop s-ui

elif command -v rc-service >/dev/null;then

rc-service s-ui stop

fi

}


install_sui(){

load

install_dep

mkdir -p "$BASE"

echo "当前仓库:"
echo "https://github.com/$REPO_USER/$REPO_NAME"

read -p "版本(空=最新版): " VERSION


if [ -z "$VERSION" ];then

URL="https://github.com/$REPO_USER/$REPO_NAME/releases/latest/download/s-ui-linux-amd64.tar.gz"

else

URL="https://github.com/$REPO_USER/$REPO_NAME/releases/download/$VERSION/s-ui-linux-amd64.tar.gz"

fi


echo "下载:"
echo "$URL"


wget -O /tmp/s-ui.tar.gz "$URL" || exit 1


tar zxvf /tmp/s-ui.tar.gz -C "$BASE"


chmod +x "$BIN"



echo
echo "开始初始化s-ui"

read -p "面板端口 [$PORT]: " x
[ -n "$x" ]&&PORT="$x"


read -p "订阅端口 [$SUBPORT]: " x
[ -n "$x" ]&&SUBPORT="$x"


read -p "管理员用户名: " ADMIN


read -s -p "管理员密码: " PASSWORD
echo


save


cd "$BASE"


./sui setting -path "$BASE"

./sui setting -port "$PORT"

./sui setting -subPort "$SUBPORT"

./sui admin -username "$ADMIN" -password "$PASSWORD"


service_create

service_enable

service_start


cp "$0" "$SCRIPT"
chmod +x "$SCRIPT"

create_short


echo
echo "================"
echo "安装完成"
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

echo "s-ui已启动"

}


stop_sui(){

service_stop

echo "s-ui已停止"

}


upgrade_sui(){

load

if ! installed;then
echo "s-ui未安装"
return
fi


cd "$BASE"

if [ -f "./sui" ];then

./sui update

service_start

echo "升级完成"

else

echo "未找到sui程序"

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

echo "修改完成"

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

echo "修改完成"

}


change_admin(){

if ! installed;then
echo "s-ui未安装"
return
fi


read -p "新的用户名:" u

read -s -p "新的密码:" p
echo


cd "$BASE"

./sui admin -username "$u" -password "$p"


service_restart


echo "管理员修改完成"

}


service_restart(){

if command -v systemctl >/dev/null;then

systemctl restart s-ui

elif command -v rc-service >/dev/null;then

rc-service s-ui restart

fi

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


echo "目录:$BASE"

echo "面板端口:$PORT"

echo "订阅端口:$SUBPORT"



if command -v systemctl >/dev/null;then

echo

systemctl status s-ui --no-pager

elif command -v rc-service >/dev/null;then

echo

rc-service s-ui status

else

echo "无服务管理器"

fi


}


log_sui(){


if command -v journalctl >/dev/null;then

journalctl -u s-ui -n 50 --no-pager

elif [ -f /var/log/s-ui.log ];then

tail -50 /var/log/s-ui.log

else

echo "没有日志"

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

echo "停止服务"

service_stop


rm -rf "$BASE"


rm -f /etc/systemd/system/s-ui.service

rm -f /etc/init.d/s-ui


systemctl daemon-reload 2>/dev/null


echo "s-ui已卸载"

}


delete_script(){

rm -f "$SCRIPT"

rm -f "$SHORT"

rm -f "$CONF"


echo "脚本和suio已删除"

exit

}
menu(){

load

create_short

clear

echo "======================"
echo "       s-ui管理器 v4"
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

read -p "请选择:" n


case "$n" in

1)
start_sui
;;

2)
stop_sui
;;

3)
install_sui
;;

4)
uninstall_sui
;;

5)
upgrade_sui
;;

6)
change_port
;;

7)
change_subport
;;

8)
change_admin
;;

9)
status_sui
;;

10)
change_repo
;;

11)
log_sui
;;

12)
delete_script
;;

0)
exit
;;

*)
menu
;;

esac

}


menu
