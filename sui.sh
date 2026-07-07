#!/bin/sh
# s-ui manager v2
# github.com/emmfax/demo

CONF="/etc/sui-manager.conf"
CMD="/usr/local/bin/suio"

[ "$(id -u)" != "0" ]&&echo "请使用root运行"&&exit 1

load(){
[ -f "$CONF" ]&&. "$CONF"
REPO_USER=${REPO_USER:-alireza0}
REPO_NAME=${REPO_NAME:-s-ui}
PATH_SUI=${PATH_SUI:-/usr/local/s-ui}
PORT=${PORT:-2095}
SUBPORT=${SUBPORT:-2096}
}

save(){
cat >$CONF <<EOF
REPO_USER=$REPO_USER
REPO_NAME=$REPO_NAME
PATH_SUI=$PATH_SUI
PORT=$PORT
SUBPORT=$SUBPORT
EOF
}

dep(){
command -v apk >/dev/null&&apk add curl wget tar gzip >/dev/null 2>&1
command -v apt >/dev/null&&apt update >/dev/null 2>&1&&apt install -y curl wget tar gzip >/dev/null 2>&1
}

find_sui(){
if [ -f "$PATH_SUI/sui" ];then
return
fi
X=$(find /usr /opt /root -name sui -type f 2>/dev/null|head -1)
[ -n "$X" ]&&PATH_SUI=$(dirname "$X")
}

restart(){
systemctl restart s-ui 2>/dev/null
rc-service s-ui restart 2>/dev/null
}

enable(){
systemctl enable s-ui 2>/dev/null
rc-update add s-ui default 2>/dev/null
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

shortcut(){

cat >$CMD <<EOF
#!/bin/sh
/usr/local/bin/sui.sh
EOF

chmod +x $CMD
hash -r 2>/dev/null

}

install(){

load
dep

mkdir -p "$PATH_SUI"

echo "仓库:"
echo "https://github.com/$REPO_USER/$REPO_NAME"

read -p "版本(空=最新版): " v

if [ -z "$v" ];then
url="https://github.com/$REPO_USER/$REPO_NAME/releases/latest/download/s-ui-linux-amd64.tar.gz"
else
url="https://github.com/$REPO_USER/$REPO_NAME/releases/download/$v/s-ui-linux-amd64.tar.gz"
fi

wget -O /tmp/sui.tar.gz "$url"||exit

tar zxvf /tmp/sui.tar.gz -C "$PATH_SUI"

chmod +x "$PATH_SUI/sui"

echo

read -p "安装路径 [$PATH_SUI]:" x
[ -n "$x" ]&&PATH_SUI=$x

read -p "面板端口 [$PORT]:" x
[ -n "$x" ]&&PORT=$x

read -p "订阅端口 [$SUBPORT]:" x
[ -n "$x" ]&&SUBPORT=$x

save

cd "$PATH_SUI"

./sui setting -port "$PORT"
./sui setting -subPort "$SUBPORT"

create_service
enable
restart

shortcut

echo "安装完成"
}

uninstall(){

load

systemctl stop s-ui 2>/dev/null
rc-service s-ui stop 2>/dev/null

rm -rf "$PATH_SUI"
rm -f /etc/systemd/system/s-ui.service
rm -f /etc/init.d/s-ui
rm -f $CMD
rm -f $CONF

systemctl daemon-reload 2>/dev/null

echo "卸载完成"
}


upgrade(){

load
find_sui

cd "$PATH_SUI"

./sui update 2>/dev/null||echo "请重新安装最新版"

restart
}


change_port(){

load
find_sui

read -p "新端口:" PORT

cd "$PATH_SUI"

./sui setting -port "$PORT"

save
restart

}


change_subport(){

load
find_sui

read -p "新订阅端口:" SUBPORT

cd "$PATH_SUI"

./sui setting -subPort "$SUBPORT"

save
restart

}


change_user(){

load
find_sui

read -p "用户名:" u

cd "$PATH_SUI"

./sui admin -username "$u"

restart
}


change_pass(){

load
find_sui

read -s -p "密码:" p
echo

cd "$PATH_SUI"

./sui admin -password "$p"

restart
}


change_path(){

load
find_sui

read -p "新路径:" p

systemctl stop s-ui 2>/dev/null
rc-service s-ui stop 2>/dev/null

mkdir -p "$p"

mv "$PATH_SUI"/* "$p"/

PATH_SUI="$p"

save

create_service
restart

}


status(){

systemctl status s-ui --no-pager 2>/dev/null||
rc-service s-ui status 2>/dev/null

}


repo(){

load

read -p "GitHub用户名 [$REPO_USER]:" x
[ -n "$x" ]&&REPO_USER=$x

read -p "仓库名 [$REPO_NAME]:" x
[ -n "$x" ]&&REPO_NAME=$x

save

}


remove(){

rm -f /usr/local/bin/sui.sh
rm -f /usr/local/bin/suio
rm -f /etc/sui-manager.conf

hash -r

echo "管理脚本已删除"

exit
}


menu(){

load

clear

find_sui

echo "================="
echo " s-ui 管理器 v2"
echo "================="

if [ -f "$PATH_SUI/sui" ];then
echo "状态: 已安装"
else
echo "状态: 未安装"
fi

echo
echo "1 安装"
echo "2 卸载"
echo "3 升级"
echo "4 修改面板端口"
echo "5 修改订阅端口"
echo "6 修改用户名"
echo "7 修改密码"
echo "8 修改路径"
echo "9 查看状态"
echo "10 修改仓库"
echo "11 删除脚本"
echo "0 退出"

read -p "选择:" n

case $n in
1)install;;
2)uninstall;;
3)upgrade;;
4)change_port;;
5)change_subport;;
6)change_user;;
7)change_pass;;
8)change_path;;
9)status;;
10)repo;;
11)remove;;
0)exit;;
*)menu;;
esac

}

menu
