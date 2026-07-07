#!/bin/sh
# s-ui manager Ver 1.1

VER="1.1"

BASE="/usr/local/s-ui"
SUI="$BASE/sui"
ONE="$BASE/one.sh"
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


installed(){
[ -x "$SUI" ]
}


running(){

if command -v systemctl >/dev/null;then

systemctl is-active --quiet s-ui
return $?

fi


if command -v rc-service >/dev/null;then

rc-service s-ui status >/dev/null 2>&1
return $?

fi


return 1

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



arch(){

case "$(uname -m)" in

x86_64)
echo amd64
;;

aarch64)
echo arm64
;;

arm64)
echo arm64
;;

*)
echo amd64
;;

esac

}



create_suio(){

cat >/usr/local/bin/suio <<EOF
#!/bin/sh
/usr/local/s-ui/one.sh
EOF

chmod +x /usr/local/bin/suio

hash -r 2>/dev/null

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

depend(){
after net
}

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

return

fi


if command -v rc-service >/dev/null;then

rc-service s-ui start

fi

}



service_stop(){

if command -v systemctl >/dev/null;then

systemctl stop s-ui

return

fi


if command -v rc-service >/dev/null;then

rc-service s-ui stop

fi

}



service_restart(){

if command -v systemctl >/dev/null;then

systemctl restart s-ui

return

fi


if command -v rc-service >/dev/null;then

rc-service s-ui restart

fi

}
#!/bin/sh
# s-ui manager Ver 1.1

VER="1.1"

BASE="/usr/local/s-ui"
SUI="$BASE/sui"
ONE="$BASE/one.sh"
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


installed(){
[ -x "$SUI" ]
}


running(){

if command -v systemctl >/dev/null;then

systemctl is-active --quiet s-ui
return $?

fi


if command -v rc-service >/dev/null;then

rc-service s-ui status >/dev/null 2>&1
return $?

fi


return 1

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



arch(){

case "$(uname -m)" in

x86_64)
echo amd64
;;

aarch64)
echo arm64
;;

arm64)
echo arm64
;;

*)
echo amd64
;;

esac

}



create_suio(){

cat >/usr/local/bin/suio <<EOF
#!/bin/sh
/usr/local/s-ui/one.sh
EOF

chmod +x /usr/local/bin/suio

hash -r 2>/dev/null

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

depend(){
after net
}

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

return

fi


if command -v rc-service >/dev/null;then

rc-service s-ui start

fi

}



service_stop(){

if command -v systemctl >/dev/null;then

systemctl stop s-ui

return

fi


if command -v rc-service >/dev/null;then

rc-service s-ui stop

fi

}



service_restart(){

if command -v systemctl >/dev/null;then

systemctl restart s-ui

return

fi


if command -v rc-service >/dev/null;then

rc-service s-ui restart

fi

}
status_sui(){

load

echo "======================"
echo "s-ui状态 Ver $VER"
echo "======================"

if installed;then
echo "安装状态: 已安装"
else
echo "安装状态: 未安装"
fi

echo

echo "路径: $SUI"
echo "目录: $BASE"
echo "面板端口: $PORT"
echo "订阅端口: $SUBPORT"


if running;then

echo "运行状态: 运行中"

else

echo "运行状态: 未运行"

fi


echo


if command -v systemctl >/dev/null;then

systemctl status s-ui --no-pager

elif command -v rc-service >/dev/null;then

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


read -p "GitHub用户名 [$REPO_USER]: " X

[ -n "$X" ]&&REPO_USER="$X"



read -p "GitHub仓库 [$REPO_NAME]: " X

[ -n "$X" ]&&REPO_NAME="$X"



save


echo "仓库修改完成"

}



uninstall_sui(){


if ! installed;then

echo "s-ui未安装"

return

fi



service_stop



rm -f "$SUI"



rm -f /etc/systemd/system/s-ui.service

rm -f /etc/init.d/s-ui



systemctl daemon-reload 2>/dev/null



echo

echo "s-ui本体已删除"

echo "管理脚本保留"

}



delete_script(){


rm -f "$ONE"

rm -f "$SHORT"


echo

echo "管理脚本已删除"

exit

}




menu(){


load


clear


echo "======================"

echo "      s-ui管理器"

echo "        Ver $VER"

echo "======================"


if installed;then

echo "安装状态: 已安装"

else

echo "安装状态: 未安装"

fi


if running;then

echo "运行状态: 运行中"

else

echo "运行状态: 未运行"

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

echo "12. 删除管理脚本"

echo

echo "0. 退出"

echo


read -p "请选择:" N



case "$N" in


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

echo "错误选择"

;;

esac



echo

read -p "按回车返回菜单"



menu

}



menu
