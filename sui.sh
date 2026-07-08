#!/bin/sh
VER="0.15"
BASE="/usr/local/s-ui"
SUI="$BASE/sui"
SERVICE="s-ui"
ONE="/usr/local/one.sh"
SHORT="/usr/local/bin/suio"
SCRIPT_URL="https://sui.upb.cc"
REPO_USER="alireza0"
REPO_NAME="s-ui"

[ "$(id -u)" != "0" ]&&echo "请使用root运行"&&exit 1
[ -t 0 ]||exec </dev/tty

is_systemd(){
command -v systemctl >/dev/null
}

is_openrc(){
command -v rc-service >/dev/null
}

cleanup(){
rm -f /tmp/sui.sh /tmp/s-ui.tar.gz
rm -rf /tmp/s-ui-update
rm -f "$ONE.tmp"
rm -f ./sui.sh /root/sui.sh
hash -r 2>/dev/null
}

installed(){
[ -x "$SUI" ]
}

running(){
pgrep -f "$SUI" >/dev/null 2>&1
}

check_port(){
case "$1" in
''|*[!0-9]*) return 1;;
esac
[ "$1" -ge 1 ]&&[ "$1" -le 65535 ]
}

check_user(){
[ -n "$1" ]||return 1
case "$1" in
*[!a-zA-Z0-9_-]*) return 1;;
*) return 0;;
esac
}

check_file(){
grep -q "#!/bin/sh" "$1" 2>/dev/null
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
if is_systemd;then
cat >/etc/systemd/system/$SERVICE.service <<EOF
[Unit]
Description=$SERVICE
After=network.target
[Service]
WorkingDirectory=$BASE
ExecStart=$SUI
Restart=always
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
else
cat >/etc/init.d/$SERVICE <<EOF
#!/sbin/openrc-run
name="$SERVICE"
command="$SUI"
command_background=true
pidfile="/run/$SERVICE.pid"
command_user="root"
depend(){
after net
}
EOF
chmod +x /etc/init.d/$SERVICE
fi
}

service_enable(){
if is_systemd;then
systemctl enable $SERVICE >/dev/null 2>&1
elif command -v rc-update >/dev/null;then
rc-update add $SERVICE default >/dev/null 2>&1
fi
}

service_start(){
if is_systemd;then
systemctl start $SERVICE
elif is_openrc;then
chmod +x /etc/init.d/$SERVICE 2>/dev/null
rc-service $SERVICE start
fi
}

service_stop(){
if is_systemd;then
systemctl stop $SERVICE >/dev/null 2>&1
elif is_openrc;then
chmod +x /etc/init.d/$SERVICE 2>/dev/null
rc-service $SERVICE stop >/dev/null 2>&1
fi
}

service_restart(){
service_stop
sleep 1
service_start
}

create_suio(){
[ -x "$ONE" ]||return
cat >"$SHORT" <<EOF
#!/bin/sh
/usr/local/one.sh
EOF
chmod +x "$SHORT"
}

cleanup
download_sui(){
dep
case "$(arch)" in
amd64) FILE="s-ui-linux-amd64.tar.gz";;
arm64) FILE="s-ui-linux-arm64.tar.gz";;
esac
wget -qO /tmp/s-ui.tar.gz "https://github.com/$REPO_USER/$REPO_NAME/releases/latest/download/$FILE"&&[ -s /tmp/s-ui.tar.gz ]
}

install_script(){
echo "安装/升级管理脚本"

if wget -qO "$ONE.tmp" "$SCRIPT_URL"&&[ -s "$ONE.tmp" ]&&check_file "$ONE.tmp";then
mv "$ONE.tmp" "$ONE"
chmod +x "$ONE"
create_suio
echo "管理脚本安装完成"
else
rm -f "$ONE.tmp"
echo "管理脚本下载失败"
fi
}

find_sui(){
find "$1" -type f -name sui 2>/dev/null|head -1
}

install_wait(){
echo "正在安装S-UI"
for i in 1 2 3 4 5
do
printf "\r安装进度 ["
case "$i" in
1) printf "■    ";;
2) printf "■■   ";;
3) printf "■■■  ";;
4) printf "■■■■ ";;
5) printf "■■■■■";;
esac
printf "]"
sleep 1
done
echo
}

input_user(){
while :;do
read -p "管理员用户名: " USER
if [ -z "$USER" ];then
echo "用户名不能为空"
continue
fi
check_user "$USER"&&break
echo "用户名只能包含英文、数字、_、-"
done
}

input_pass(){
while :;do
read -p "管理员密码: " PASS
[ -n "$PASS" ]&&break
echo "密码不能为空"
done
}

install_sui(){
if installed;then
read -p "S-UI已安装，继续覆盖? [y/N]: " X
[ "$X" = "y" ]||[ "$X" = "Y" ]||return
fi

echo "======================"
echo "s-ui安装 Ver $VER"
echo "======================"

while :;do
read -p "面板端口 [2095]: " PORT
[ -z "$PORT" ]&&PORT=2095
check_port "$PORT"&&break
echo "端口错误"
done

while :;do
read -p "订阅端口 [2096]: " SUB
[ -z "$SUB" ]&&SUB=2096
check_port "$SUB"&&break
echo "端口错误"
done

read -p "面板路径 [app]: " PATHSET
[ -z "$PATHSET" ]&&PATHSET=app

read -p "订阅路径 [sub]: " SUBPATH
[ -z "$SUBPATH" ]&&SUBPATH=sub

input_user
input_pass

install_wait

if ! download_sui;then
echo "S-UI下载失败"
cleanup
return
fi

rm -rf "$BASE"
mkdir -p "$BASE"

if ! tar zxf /tmp/s-ui.tar.gz -C "$BASE";then
rm -rf "$BASE"
echo "解压失败"
cleanup
return
fi

if [ -d "$BASE/s-ui" ];then
mv "$BASE/s-ui"/* "$BASE"/
rm -rf "$BASE/s-ui"
fi

F=$(find_sui "$BASE")

if [ -z "$F" ];then
rm -rf "$BASE"
echo "安装文件错误"
cleanup
return
fi

mv "$F" "$SUI"
chmod +x "$SUI"

cd "$BASE"||return

./sui setting -port "$PORT"
./sui setting -subPort "$SUB"
./sui setting -path "$PATHSET"
./sui setting -subPath "$SUBPATH"
./sui admin -username "$USER" -password "$PASS"

service_create
service_enable
service_start

sleep 2

if running;then
echo "S-UI启动成功"
else
echo "S-UI启动失败，请查看状态"
fi

install_script

cleanup

echo
echo "s-ui安装完成"
[ -x "$SHORT" ]&&echo "快捷命令:suio"
}

start_sui(){
if ! installed;then
echo "S-UI未安装"
return
fi

if running;then
echo "S-UI已经运行"
return
fi

service_start
sleep 2

running&&echo "S-UI启动成功"||echo "S-UI启动失败"
}

stop_sui(){
if ! installed;then
echo "S-UI未安装"
return
fi

if ! running;then
echo "S-UI未运行"
return
fi

service_stop
sleep 1

running&&echo "S-UI停止失败"||echo "S-UI已停止"
}

change_port(){
if ! installed;then
echo "S-UI未安装"
return
fi

while :;do
read -p "新的面板端口: " P
check_port "$P"&&break
echo "端口错误"
done

cd "$BASE"
./sui setting -port "$P"&&service_restart&&echo "修改完成"||echo "修改失败"
}

change_sub(){
if ! installed;then
echo "S-UI未安装"
return
fi

while :;do
read -p "新的订阅端口: " P
check_port "$P"&&break
echo "端口错误"
done

cd "$BASE"
./sui setting -subPort "$P"&&service_restart&&echo "修改完成"||echo "修改失败"
}

change_path(){
if ! installed;then
echo "S-UI未安装"
return
fi

read -p "新的面板路径 [app]: " P
[ -z "$P" ]&&P=app

cd "$BASE"
./sui setting -path "$P"&&service_restart&&echo "修改完成"||echo "修改失败"
}

change_sub_path(){
if ! installed;then
echo "S-UI未安装"
return
fi

read -p "新的订阅路径 [sub]: " P
[ -z "$P" ]&&P=sub

cd "$BASE"
./sui setting -subPath "$P"&&service_restart&&echo "修改完成"||echo "修改失败"
}
change_admin(){
if ! installed;then
echo "S-UI未安装"
return
fi

input_user
input_pass

cd "$BASE"
./sui admin -username "$USER" -password "$PASS"&&service_restart&&echo "修改完成"||echo "修改失败"
}

status_sui(){
if ! installed;then
echo "S-UI未安装"
return
fi

echo "======================"
echo "S-UI真实状态"
echo "======================"

if is_systemd;then
systemctl status $SERVICE --no-pager
elif is_openrc;then
chmod +x /etc/init.d/$SERVICE 2>/dev/null
rc-service $SERVICE status
else
echo "无法检测服务状态"
fi
}

change_repo(){
read -p "GitHub用户名 [$REPO_USER]: " U
[ -n "$U" ]&&REPO_USER="$U"

read -p "GitHub仓库 [$REPO_NAME]: " R
[ -n "$R" ]&&REPO_NAME="$R"

echo "修改完成"
}

uninstall_sui(){
if ! installed;then
echo "S-UI未安装"
return
fi

echo "卸载S-UI"

if is_systemd;then
systemctl stop $SERVICE >/dev/null 2>&1
systemctl disable $SERVICE >/dev/null 2>&1
else
command -v rc-update >/dev/null&&rc-update del $SERVICE default >/dev/null 2>&1
is_openrc&&chmod +x /etc/init.d/$SERVICE 2>/dev/null&&rc-service $SERVICE stop >/dev/null 2>&1
fi

rm -rf "$BASE"
rm -f /etc/systemd/system/$SERVICE.service
rm -f /etc/init.d/$SERVICE
rm -f /run/$SERVICE.pid

systemctl daemon-reload 2>/dev/null

echo "S-UI卸载完成"
}

delete_script(){
echo "确认删除管理脚本? [y/N]"
read -r X

case "$X" in
y|Y)
rm -f "$ONE" "$SHORT"
hash -r 2>/dev/null
echo "管理脚本删除完成"
exit
;;
*)
echo "取消删除"
;;
esac
}

pause(){
read -p "按回车返回菜单"
}

menu(){
while :
do
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
echo "12. 安装/升级管理脚本"
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
12) install_script;;
13) delete_script;;
0) exit;;
*) echo "错误选择";;
esac

pause
done
}

menu
