#!/bin/sh
VER="1.7"
BASE="/usr/local/s-ui"
SUI="$BASE/sui"
ONE="/usr/local/one.sh"
SHORT="/usr/local/bin/suio"
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
download_sui(){
dep
case "$(arch)" in
amd64) FILE="s-ui-linux-amd64.tar.gz";;
arm64) FILE="s-ui-linux-arm64.tar.gz";;
esac
wget -qO /tmp/s-ui.tar.gz "https://github.com/$REPO_USER/$REPO_NAME/releases/latest/download/$FILE"
}

find_sui(){
find "$1" -type f -name sui 2>/dev/null|head -1
}

install_sui(){
echo "======================"
echo "s-ui安装 Ver $VER"
echo "======================"

read -p "版本 [最新版]: " V
read -p "面板端口 [2095]: " PORT
[ -z "$PORT" ]&&PORT=2095
read -p "订阅端口 [2096]: " SUB
[ -z "$SUB" ]&&SUB=2096
read -p "面板路径 [app]: " PATHSET
[ -z "$PATHSET" ]&&PATHSET=app

while :;do
read -p "管理员用户名: " USER
[ -n "$USER" ]&&break
echo "用户名不能为空"
done

while :;do
read -s -p "管理员密码: " PASS
echo
[ -n "$PASS" ]&&break
echo "密码不能为空"
done

download_sui||{
echo "下载失败"
return
}

rm -rf "$BASE"
mkdir -p "$BASE"

tar zxf /tmp/s-ui.tar.gz -C "$BASE"

if [ -d "$BASE/s-ui" ];then
mv "$BASE/s-ui"/* "$BASE"/
rm -rf "$BASE/s-ui"
fi

F=$(find_sui "$BASE")
[ -n "$F" ]&&mv "$F" "$SUI"

chmod +x "$SUI"

if ! installed;then
echo "s-ui安装失败"
return
fi

cd "$BASE"

./sui setting -port "$PORT"
./sui setting -subPort "$SUB"
./sui setting -path "$PATHSET"
./sui admin -username "$USER" -password "$PASS"

service_create
service_enable
service_start

wget -qO "$ONE" https://raw.githubusercontent.com/emmfax/demo/main/sui.sh

if [ -s "$ONE" ];then
chmod +x "$ONE"
create_suio
else
rm -f "$ONE"
echo "管理脚本下载失败"
fi

cleanup

echo
echo "s-ui安装完成"
echo "快捷命令:suio"
}

start_sui(){
if ! installed;then
echo "S-UI未安装"
return
fi

if running;then
echo "S-UI正在运行"
return
fi

service_start
sleep 2

if running;then
echo "S-UI运行中"
else
echo "S-UI启动失败"
fi
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

if running;then
echo "S-UI停止失败"
else
echo "S-UI已停止"
fi
}

change_port(){
if ! installed;then
echo "S-UI未安装"
return
fi

read -p "新的面板端口: " P
cd "$BASE"
./sui setting -port "$P"
service_restart
echo "修改完成"
}

change_sub(){
if ! installed;then
echo "S-UI未安装"
return
fi

read -p "新的订阅端口: " P
cd "$BASE"
./sui setting -subPort "$P"
service_restart
echo "修改完成"
}

change_path(){
if ! installed;then
echo "S-UI未安装"
return
fi

read -p "新的面板路径 [app]: " P
[ -z "$P" ]&&P=app

cd "$BASE"
./sui setting -path "$P"
service_restart
echo "修改完成"
}

change_admin(){
if ! installed;then
echo "S-UI未安装"
return
fi

read -p "管理员用户名: " U
read -s -p "管理员密码: " P
echo

cd "$BASE"
./sui admin -username "$U" -password "$P"
service_restart
echo "修改完成"
}
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
echo "程序路径:$SUI"
echo "安装目录:$BASE"
}

change_repo(){
read -p "GitHub用户名 [$REPO_USER]: " U
[ -n "$U" ]&&REPO_USER="$U"

read -p "GitHub仓库 [$REPO_NAME]: " R
[ -n "$R" ]&&REPO_NAME="$R"

echo "仓库修改完成"
}

update_script(){
echo "升级管理脚本"

wget -qO "$ONE" https://raw.githubusercontent.com/emmfax/demo/main/sui.sh

if [ -s "$ONE" ];then
chmod +x "$ONE"
echo "升级完成"
else
rm -f "$ONE"
echo "升级失败"
fi
}

uninstall_sui(){
echo "开始卸载S-UI"

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
echo "5. 查看状态"
echo "6. 修改面板端口"
echo "7. 修改订阅端口"
echo "8. 面板路径设置"
echo "9. 修改管理员账号密码"
echo "10. 修改安装仓库"
echo "11. 升级管理脚本"
echo "12. 删除管理脚本"
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
9) change_admin;;
10) change_repo;;
11) update_script;;
12) delete_script;;
0) exit;;
*) echo "错误选择";;
esac

pause
menu
}

menu
