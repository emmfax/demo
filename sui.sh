#!/bin/sh
VER="1.9.1"
BASE="/usr/local/s-ui"
SUI="$BASE/sui"
ONE="/usr/local/one.sh"
SHORT="/usr/local/bin/suio"
SCRIPT_URL="https://sui.upb.cc"
REPO_USER="alireza0"
REPO_NAME="s-ui"

[ "$(id -u)" != "0" ]&&echo "请使用root运行"&&exit 1
[ -t 0 ]||exec </dev/tty

cleanup(){
rm -f /tmp/sui.sh /tmp/s-ui.tar.gz
rm -rf /tmp/s-ui-update
rm -f /root/sui.sh ./sui.sh
hash -r 2>/dev/null
}

installed(){
[ -x "$SUI" ]
}

running(){
pidof sui >/dev/null 2>&1
}

check_port(){
echo "$1"|grep -q '^[0-9]\+$'||return 1
[ "$1" -ge 1 ]&&[ "$1" -le 65535 ]
}

check_user(){
[ -n "$1" ]&&echo "$1"|grep -q '^[a-zA-Z0-9_-]\+$'
}

dep(){
if command -v apk >/dev/null;then
apk add --no-cache wget curl tar gzip >/dev/null 2>&1
elif command -v apt >/dev/null;then
apt update >/dev/null 2>&1
apt install -y wget curl tar gzip >/dev/null 2>&1
fi
}

arch(){
case "$(uname -m)" in
x86_64|amd64) echo amd64;;
aarch64|arm64) echo arm64;;
*) echo amd64;;
esac
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

service_restart(){
service_stop
sleep 1
service_start
}

create_suio(){
cat >"$SHORT" <<EOF
#!/bin/sh
/usr/local/one.sh
EOF
chmod +x "$SHORT"
}

cleanup
#!/bin/sh
VER="1.9.1"
BASE="/usr/local/s-ui"
SUI="$BASE/sui"
ONE="/usr/local/one.sh"
SHORT="/usr/local/bin/suio"
SCRIPT_URL="https://sui.upb.cc"
REPO_USER="alireza0"
REPO_NAME="s-ui"

[ "$(id -u)" != "0" ]&&echo "请使用root运行"&&exit 1
[ -t 0 ]||exec </dev/tty

cleanup(){
rm -f /tmp/sui.sh /tmp/s-ui.tar.gz
rm -rf /tmp/s-ui-update
rm -f /root/sui.sh ./sui.sh
hash -r 2>/dev/null
}

installed(){
[ -x "$SUI" ]
}

running(){
pidof sui >/dev/null 2>&1
}

check_port(){
echo "$1"|grep -q '^[0-9]\+$'||return 1
[ "$1" -ge 1 ]&&[ "$1" -le 65535 ]
}

check_user(){
[ -n "$1" ]&&echo "$1"|grep -q '^[a-zA-Z0-9_-]\+$'
}

dep(){
if command -v apk >/dev/null;then
apk add --no-cache wget curl tar gzip >/dev/null 2>&1
elif command -v apt >/dev/null;then
apt update >/dev/null 2>&1
apt install -y wget curl tar gzip >/dev/null 2>&1
fi
}

arch(){
case "$(uname -m)" in
x86_64|amd64) echo amd64;;
aarch64|arm64) echo arm64;;
*) echo amd64;;
esac
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

service_restart(){
service_stop
sleep 1
service_start
}

create_suio(){
cat >"$SHORT" <<EOF
#!/bin/sh
/usr/local/one.sh
EOF
chmod +x "$SHORT"
}

cleanup
status_sui(){
echo "======================"
echo "s-ui状态 Ver $VER"
echo "======================"

if ! installed;then
echo "安装状态: 未安装"
echo "运行状态: 未运行"
return
fi

echo "安装状态: 已安装"

if running;then
echo "运行状态: 运行中"
else
echo "运行状态: 未运行"
fi

echo
echo "程序路径: $SUI"
echo "安装目录: $BASE"
}

change_repo(){
read -p "GitHub用户名 [$REPO_USER]: " U
[ -n "$U" ]&&REPO_USER="$U"

read -p "GitHub仓库 [$REPO_NAME]: " R
[ -n "$R" ]&&REPO_NAME="$R"

echo "修改完成"
}

update_script(){
echo "升级管理脚本"

rm -f "$ONE"

if wget -qO "$ONE" "$SCRIPT_URL"&&[ -s "$ONE" ];then
chmod +x "$ONE"
echo "升级完成"
else
rm -f "$ONE"
echo "升级失败"
fi
}

uninstall_sui(){
echo "卸载S-UI"

service_stop

rm -rf /usr/local/s-ui
rm -f /etc/systemd/system/s-ui.service
rm -f /etc/init.d/s-ui

systemctl daemon-reload 2>/dev/null

echo "S-UI卸载完成"
}

delete_script(){
rm -f /usr/local/one.sh
rm -f /usr/local/bin/suio
exit
}

pause(){
read -p "按回车返回菜单"
}

menu(){
clear

echo "======================"
echo "      s-ui管理器"
echo "       Ver $VER"
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
echo "5. 查看状态"
echo "6. 修改面板端口"
echo "7. 修改订阅端口"
echo "8. 修改面板路径"
echo "9. 修改订阅路径"
echo "10. 修改管理员账号密码"
echo "11. 修改安装仓库"
echo "12. 升级管理脚本"
echo "13. 删除管理脚本"
echo
echo "0. 退出"

read -p "请选择: " N

case "$N" in
1) start_sui;;
2) stop_sui;;
3) install_sui;;
4) uninstall_sui;;
5) status_sui;;
6) change_port;;
7) change_sub;;
8) change_path;;
9) change_sub_path;;
10) change_admin;;
11) change_repo;;
12) update_script;;
13) delete_script;;
0) exit;;
*) echo "错误选择";;
esac

pause
menu
}

menu
