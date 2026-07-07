#!/bin/sh
VER="1.5"
BASE="/usr/local/s-ui"
SUI="$BASE/sui"
ONE="/usr/local/one.sh"
SHORT="/usr/local/bin/suio"
REPO_USER="alireza0"
REPO_NAME="s-ui"

[ "$(id -u)" != "0" ]&&echo "请使用root运行"&&exit 1

cleanup(){
rm -f /tmp/s-ui.tar.gz
rm -rf /tmp/s-ui-update*
hash -r 2>/dev/null
}

installed(){
[ -x "$SUI" ]
}

running(){
if [ ! -x "$SUI" ];then
return 1
fi
if command -v pidof >/dev/null;then
pidof sui >/dev/null 2>&1&&return 0
fi
if command -v systemctl >/dev/null;then
systemctl is-active --quiet s-ui&&return 0
fi
if command -v rc-service >/dev/null;then
rc-service s-ui status >/dev/null 2>&1&&return 0
fi
return 1
}

dep(){
if command -v apk >/dev/null;then
apk add --no-cache wget curl tar gzip >/dev/null 2>&1
fi
if command -v apt >/dev/null;then
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

create_suio(){
cat >/usr/local/bin/suio <<EOF
#!/bin/sh
/usr/local/one.sh
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
return
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
service_stop
sleep 1
service_start
}

cleanup
download_sui(){
dep
case "$(arch)" in
amd64) FILE="s-ui-linux-amd64.tar.gz";;
arm64) FILE="s-ui-linux-arm64.tar.gz";;
esac
if [ -n "$1" ];then
URL="https://github.com/$REPO_USER/$REPO_NAME/releases/download/$1/$FILE"
else
URL="https://github.com/$REPO_USER/$REPO_NAME/releases/latest/download/$FILE"
fi
wget -O /tmp/s-ui.tar.gz "$URL"
}

find_sui(){
find "$1" -type f -name sui 2>/dev/null|head -1
}

install_sui(){
mkdir -p "$BASE"
echo "======================"
echo "s-ui安装 Ver $VER"
echo "======================"
read -p "版本(空=最新版): " V
download_sui "$V"||{
echo "下载失败"
return
}
rm -rf "$BASE"/*
tar zxvf /tmp/s-ui.tar.gz -C "$BASE"
if [ -d "$BASE/s-ui" ];then
mv "$BASE/s-ui"/* "$BASE"/
rm -rf "$BASE/s-ui"
fi
F=$(find_sui "$BASE")
[ -n "$F" ]&&mv "$F" "$SUI"
chmod +x "$SUI"
if ! installed;then
echo "sui不存在"
return
fi
echo
echo "开始初始化s-ui"
while :;do
read -p "面板端口: " PORT
[ -n "$PORT" ]&&break
done
while :;do
read -p "订阅端口: " SUBPORT
[ -n "$SUBPORT" ]&&break
done
while :;do
read -p "面板路径 [app]: " PATH
[ -n "$PATH" ]&&break
done
while :;do
read -p "管理员用户名: " USER
[ -n "$USER" ]&&break
done
while :;do
read -s -p "管理员密码: " PASS
echo
[ -n "$PASS" ]&&break
done
cd "$BASE"
./sui setting -port "$PORT"
./sui setting -subPort "$SUBPORT"
./sui setting -path "$PATH"
./sui admin -username "$USER" -password "$PASS"
service_create
service_enable
service_start
wget -O "$ONE" https://raw.githubusercontent.com/emmfax/demo/main/sui.sh
chmod +x "$ONE"
create_suio
cleanup
if running;then
echo "S-UI运行中"
else
echo "S-UI启动失败"
fi
echo "======================"
echo "s-ui安装完成"
echo "快捷命令:suio"
echo "======================"
}

upgrade_sui(){
if ! installed;then
echo "S-UI未安装"
return
fi
echo "开始升级s-ui"
service_stop
mkdir -p /tmp/s-ui-update
download_sui||{
echo "下载失败"
return
}
tar zxvf /tmp/s-ui.tar.gz -C /tmp/s-ui-update
F=$(find_sui /tmp/s-ui-update)
if [ -z "$F" ];then
echo "未找到sui"
return
fi
cp "$SUI" "$BASE/sui.bak"
cp "$F" "$SUI"
chmod +x "$SUI"
service_start
cleanup
if running;then
echo "升级完成"
else
echo "升级失败"
fi
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
[ -z "$P" ]&&return
cd "$BASE"
./sui setting -port "$P"
service_restart
echo "修改完成"
}

change_subport(){
if ! installed;then
echo "S-UI未安装"
return
fi
read -p "新的订阅端口: " P
[ -z "$P" ]&&return
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
[ -z "$P" ]&&P="app"
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
echo "程序路径: $SUI"
echo "安装目录: $BASE"
}

log_sui(){
if command -v journalctl >/dev/null;then
journalctl -u s-ui -n 50 --no-pager
elif command -v rc-service >/dev/null;then
rc-service s-ui status
else
echo "没有日志"
fi
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
wget -O "$ONE" https://raw.githubusercontent.com/emmfax/demo/main/sui.sh
chmod +x "$ONE"
hash -r 2>/dev/null
echo "管理脚本升级完成"
}

uninstall_sui(){
if ! installed;then
echo "S-UI未安装"
return
fi
service_stop
rm -rf "$BASE"
rm -f /etc/systemd/system/s-ui.service
rm -f /etc/init.d/s-ui
systemctl daemon-reload 2>/dev/null
echo "S-UI卸载完成"
}

delete_script(){
rm -f "$SHORT"
rm -f "$ONE"
echo "脚本删除完成"
exit
}

pause(){
echo
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
echo "5. 升级 s-ui"
echo "6. 修改面板端口"
echo "7. 修改订阅端口"
echo "8. 面板路径设置"
echo "9. 查看状态"
echo "10. 查看日志"
echo "11. 修改管理员账号密码"
echo "12. 修改安装仓库"
echo "13. 升级管理脚本"
echo "14. 删除管理脚本"
echo
echo "0. 退出"

read -p "请选择: " N

case "$N" in
1) start_sui;pause;;
2) stop_sui;pause;;
3) install_sui;pause;;
4) uninstall_sui;pause;;
5) upgrade_sui;pause;;
6) change_port;pause;;
7) change_subport;pause;;
8) change_path;pause;;
9) status_sui;pause;;
10) log_sui;pause;;
11) change_admin;pause;;
12) change_repo;pause;;
13) update_script;pause;;
14) delete_script;;
0) exit;;
*) menu;;
esac

menu
}

menu
