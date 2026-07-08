#!/bin/sh
VER="0.18"
BASE="/usr/local/s-ui"
SUI="$BASE/sui"
ONE="/usr/local/one.sh"
SHORT="/usr/local/bin/suio"
CONF="/usr/local/bin/one.conf"
SERVICE="s-ui"
SCRIPT_URL="https://sui.upb.cc"

DEFAULT_REPO_USER="alireza0"
DEFAULT_REPO_NAME="s-ui"

[ "$(id -u)" != "0" ]&&echo "请使用root运行"&&exit 1
[ -c /dev/tty ]&&exec </dev/tty

confirm(){
case "$(echo "$1"|tr 'a-z' 'A-Z')" in
Y|YES) return 0;;
*) return 1;;
esac
}

pause(){
printf "\n按回车返回菜单"
read -r _
}

installed(){
[ -x "$SUI" ]
}

is_systemd(){
command -v systemctl >/dev/null 2>&1&&[ -d /run/systemd/system ]
}

is_openrc(){
command -v rc-service >/dev/null 2>&1
}

running(){
if is_systemd;then
systemctl is-active --quiet "$SERVICE"
elif is_openrc;then
rc-service "$SERVICE" status >/dev/null 2>&1
else
pidof sui >/dev/null 2>&1
fi
}

service_start(){
if is_systemd;then
systemctl start "$SERVICE" >/dev/null 2>&1
elif is_openrc;then
rc-service "$SERVICE" start >/dev/null 2>&1
else
"$SUI" start >/dev/null 2>&1
fi
sleep 1
running
}

service_stop(){
if is_systemd;then
systemctl stop "$SERVICE" >/dev/null 2>&1
elif is_openrc;then
rc-service "$SERVICE" stop >/dev/null 2>&1
else
"$SUI" stop >/dev/null 2>&1
fi
}

service_restart(){
if is_systemd;then
systemctl restart "$SERVICE" >/dev/null 2>&1
elif is_openrc;then
rc-service "$SERVICE" restart >/dev/null 2>&1
else
"$SUI" restart >/dev/null 2>&1
fi
}

dep(){
if command -v apk >/dev/null 2>&1;then
apk add --no-cache wget curl tar gzip >/dev/null 2>&1
elif command -v apt >/dev/null 2>&1;then
apt update >/dev/null 2>&1
apt install -y wget curl tar gzip >/dev/null 2>&1
fi
}

arch(){
case "$(uname -m)" in
x86_64|amd64)
echo amd64
;;
aarch64|arm64)
echo arm64
;;
*)
echo amd64
;;
esac
}

load_local(){
REPO_USER="$DEFAULT_REPO_USER"
REPO_NAME="$DEFAULT_REPO_NAME"
PANEL_PORT=""
SUB_PORT=""
PANEL_PATH=""
SUB_PATH=""

[ -f "$CONF" ]&&. "$CONF"

[ -z "$REPO_USER" ]&&REPO_USER="$DEFAULT_REPO_USER"
[ -z "$REPO_NAME" ]&&REPO_NAME="$DEFAULT_REPO_NAME"
}

save_local(){
mkdir -p /usr/local/bin

cat >"$CONF.tmp" <<EOF
PANEL_PORT="$PANEL_PORT"
SUB_PORT="$SUB_PORT"
PANEL_PATH="$PANEL_PATH"
SUB_PATH="$SUB_PATH"
REPO_USER="$REPO_USER"
REPO_NAME="$REPO_NAME"
EOF

mv "$CONF.tmp" "$CONF"
chmod 600 "$CONF"
}

clear_repo(){
[ -f "$CONF" ]||return
sed -i '/^REPO_USER=/d;/^REPO_NAME=/d' "$CONF"
}

check_port(){
case "$1" in
''|*[!0-9]*)
return 1
;;
esac

[ "$1" -ge 1 ]&&[ "$1" -le 65535 ]
}

service_create(){
if is_systemd;then
cat >/etc/systemd/system/s-ui.service <<EOF
[Unit]
Description=s-ui
After=network.target

[Service]
WorkingDirectory=$BASE
ExecStart=$SUI
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable s-ui >/dev/null 2>&1

elif is_openrc;then

cat >/etc/init.d/s-ui <<EOF
#!/sbin/openrc-run
name="s-ui"
command="$SUI"
command_background="yes"
pidfile="/run/s-ui.pid"

depend(){
need net
}
EOF

chmod +x /etc/init.d/s-ui
rc-update add s-ui default >/dev/null 2>&1
fi
}

download_sui(){
load_local
dep

rm -f /tmp/s-ui.tar.gz

URL="https://github.com/$REPO_USER/$REPO_NAME/releases/latest/download/s-ui-linux-$(arch).tar.gz"

wget -qO /tmp/s-ui.tar.gz "$URL"||return 1

mkdir -p "$BASE"

tar -xzf /tmp/s-ui.tar.gz -C "$BASE"||return 1

chmod +x "$SUI"
}

install_sui(){
if installed;then
echo "S-UI已经安装"
pause
return
fi

echo "======================"
echo "       S-UI安装"
echo "======================"

read -p "面板端口 [2095]: " PANEL_PORT
PANEL_PORT=${PANEL_PORT:-2095}

while ! check_port "$PANEL_PORT";do
echo "端口错误"
read -p "面板端口 [2095]: " PANEL_PORT
PANEL_PORT=${PANEL_PORT:-2095}
done

read -p "订阅端口 [2096]: " SUB_PORT
SUB_PORT=${SUB_PORT:-2096}

while ! check_port "$SUB_PORT";do
echo "端口错误"
read -p "订阅端口 [2096]: " SUB_PORT
SUB_PORT=${SUB_PORT:-2096}
done

read -p "面板路径 [app]: " PANEL_PATH
PANEL_PATH=${PANEL_PATH:-app}

read -p "订阅路径 [sub]: " SUB_PATH
SUB_PATH=${SUB_PATH:-sub}

read -p "是否在本地保存端口路径信息? [Y/N]: " SAVE_INFO

if confirm "$SAVE_INFO";then
SAVE_LOCAL=1
else
SAVE_LOCAL=0
fi

while :;do
read -p "管理员用户名: " USERNAME

if [ -n "$USERNAME" ]&&echo "$USERNAME"|grep -Eq '^[a-zA-Z0-9_-]+$';then
break
fi

echo "用户名只能包含英文、数字、_、-"
done

while :;do
read -p "管理员密码: " PASSWORD

if [ -n "$PASSWORD" ];then
break
fi

echo "密码不能为空"
done

echo "正在安装S-UI"

printf "["

i=0
while [ "$i" -lt 20 ];do
printf "#"
sleep 0.1
i=$((i+1))
done

printf "]\n"

if ! download_sui;then
echo "S-UI下载失败"
pause
return
fi

"$SUI" setting -port "$PANEL_PORT" >/dev/null 2>&1
"$SUI" setting -subPort "$SUB_PORT" >/dev/null 2>&1
"$SUI" setting -path "$PANEL_PATH" >/dev/null 2>&1
"$SUI" setting -subPath "$SUB_PATH" >/dev/null 2>&1

"$SUI" admin -username "$USERNAME" -password "$PASSWORD" >/dev/null 2>&1

service_create

if service_start;then
echo "S-UI启动成功"
else
echo "S-UI启动失败"
fi

if [ "$SAVE_LOCAL" = "1" ];then
save_local
echo "端口路径信息已保存"
fi

install_script

echo
echo "S-UI安装完成"
echo "快捷命令:suio"

pause
}

uninstall_sui(){
if ! installed;then
echo "S-UI未安装"
pause
return
fi

read -p "确认卸载S-UI? [Y/N]: " X

confirm "$X"||return

service_stop

if is_systemd;then
systemctl disable s-ui >/dev/null 2>&1
rm -f /etc/systemd/system/s-ui.service
systemctl daemon-reload

elif is_openrc;then
rc-update del s-ui default >/dev/null 2>&1
rm -f /etc/init.d/s-ui
fi

rm -rf "$BASE"

echo "S-UI卸载完成"

pause
}

start_sui(){
if ! installed;then
echo "S-UI未安装"
pause
return
fi

service_start&&echo "S-UI启动成功"||echo "S-UI启动失败"

pause
}

stop_sui(){
if ! installed;then
echo "S-UI未安装"
pause
return
fi

service_stop

echo "S-UI停止完成"

pause
}

status_sui(){
if ! installed;then
echo "S-UI未安装"
pause
return
fi

if is_systemd;then
systemctl status s-ui --no-pager -l

elif is_openrc;then
rc-service s-ui status

else
pidof sui
fi

pause
}
change_port(){
if ! installed;then
echo "S-UI未安装"
pause
return
fi

load_local

echo "当前面板端口:$PANEL_PORT"

while :;do
read -p "新的面板端口: " P
check_port "$P"&&break
echo "端口错误"
done

"$SUI" setting -port "$P"&&{
PANEL_PORT="$P"
[ -f "$CONF" ]&&save_local
service_restart
echo "修改完成"
}

pause
}

change_sub(){
if ! installed;then
echo "S-UI未安装"
pause
return
fi

load_local

echo "当前订阅端口:$SUB_PORT"

while :;do
read -p "新的订阅端口: " P
check_port "$P"&&break
echo "端口错误"
done

"$SUI" setting -subPort "$P"&&{
SUB_PORT="$P"
[ -f "$CONF" ]&&save_local
service_restart
echo "修改完成"
}

pause
}

change_path(){
if ! installed;then
echo "S-UI未安装"
pause
return
fi

load_local

echo "当前面板路径:$PANEL_PATH"

read -p "新的面板路径: " P

[ -z "$P" ]&&return

"$SUI" setting -path "$P"&&{
PANEL_PATH="$P"
[ -f "$CONF" ]&&save_local
service_restart
echo "修改完成"
}

pause
}

change_sub_path(){
if ! installed;then
echo "S-UI未安装"
pause
return
fi

load_local

echo "当前订阅路径:$SUB_PATH"

read -p "新的订阅路径: " P

[ -z "$P" ]&&return

"$SUI" setting -subPath "$P"&&{
SUB_PATH="$P"
[ -f "$CONF" ]&&save_local
service_restart
echo "修改完成"
}

pause
}

change_admin(){
if ! installed;then
echo "S-UI未安装"
pause
return
fi

while :;do
read -p "管理员用户名: " USERNAME

if [ -n "$USERNAME" ]&&echo "$USERNAME"|grep -Eq '^[a-zA-Z0-9_-]+$';then
break
fi

echo "用户名只能包含英文、数字、_、-"
done

while :;do
read -p "管理员密码: " PASSWORD

if [ -n "$PASSWORD" ];then
break
fi

echo "密码不能为空"
done

"$SUI" admin -username "$USERNAME" -password "$PASSWORD"&&echo "修改成功"

pause
}

change_repo(){
load_local

echo "当前仓库:$REPO_USER/$REPO_NAME"
echo
echo "D.恢复默认仓库"
echo "Y.持续化保存修改"
echo "N.返回菜单"
echo "L.临时修改"

read -p "请选择: " X

case "$(echo "$X"|tr 'a-z' 'A-Z')" in

D)
REPO_USER="$DEFAULT_REPO_USER"
REPO_NAME="$DEFAULT_REPO_NAME"

clear_repo

echo "已恢复默认仓库"
;;

Y)
read -p "GitHub用户名: " U
read -p "GitHub仓库: " R

[ -z "$U" ]||[ -z "$R" ]&&{
echo "输入不能为空"
pause
return
}

REPO_USER="$U"
REPO_NAME="$R"

save_local

echo "仓库已持续化保存"
;;

L)
read -p "GitHub用户名: " U
read -p "GitHub仓库: " R

[ -z "$U" ]||[ -z "$R" ]&&return

REPO_USER="$U"
REPO_NAME="$R"

echo "仓库临时修改完成"
echo "退出脚本后恢复默认"
;;

N)
return
;;

*)
echo "无效选择"
;;

esac

pause
}

install_script(){
mkdir -p /usr/local/bin

wget -qO "$ONE.tmp" "$SCRIPT_URL"||return 1

mv "$ONE.tmp" "$ONE"

chmod +x "$ONE"

cat >"$SHORT" <<EOF
#!/bin/sh
/usr/local/one.sh
EOF

chmod +x "$SHORT"
}

upgrade_script(){
if [ ! -f "$ONE" ];then
echo "管理脚本未安装"
pause
return
fi

install_script

echo "管理脚本升级完成"

pause
}

remove_script(){
read -p "确认删除管理脚本? [Y/N]: " X

confirm "$X"||return

rm -f "$ONE" "$SHORT" "$CONF"

hash -r 2>/dev/null

echo "管理脚本删除完成"

pause
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
echo "11. 管理安装仓库"
echo "12. 安装/升级管理脚本"
echo "13. 卸载管理脚本"
echo
echo "0. 退出"

read -p "请选择: " NUM

case "$NUM" in
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
12) upgrade_script;;
13) remove_script;;
0) exit 0;;
*)
echo "无效选择"
pause
;;
esac
}

main(){
while :;do
menu
done
}

main
