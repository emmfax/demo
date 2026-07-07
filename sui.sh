#!/bin/sh

# ==========================================
# S-UI 极简管理脚本
# 支持 Debian / Alpine
# 适合 64MB-512MB 小型容器
# ==========================================

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# ---------- 配置 ----------

CONFIG="/etc/s-ui-manager.conf"

[ -f "$CONFIG" ] && . "$CONFIG"

OWNER=${OWNER:-alireza0}
REPO=${REPO:-s-ui}

INSTALL_PATH=${INSTALL_PATH:-/usr/local/s-ui}

SERVICE_NAME="s-ui"

TMP_DIR="/tmp/s-ui-install"

# ---------- 颜色 ----------

red(){
echo "\033[31m$1\033[0m"
}

green(){
echo "\033[32m$1\033[0m"
}

yellow(){
echo "\033[33m$1\033[0m"
}


# ---------- root检测 ----------

if [ "$(id -u)" != "0" ]; then
    red "请使用root运行"
    exit 1
fi


# ---------- 系统检测 ----------

detect_os(){

if [ -f /etc/alpine-release ]; then

    OS="alpine"

elif [ -f /etc/debian_version ]; then

    OS="debian"

else

    red "不支持的系统"
    exit 1

fi

}


# ---------- 服务检测 ----------

service_exists(){

if [ -f "$INSTALL_PATH/s-ui" ]; then
    return 0
fi

return 1

}



# ---------- 服务操作 ----------

service_restart(){

echo "正在后台重启服务..."

if [ "$OS" = "alpine" ]; then

    nohup rc-service s-ui restart >/dev/null 2>&1 &

else

    nohup systemctl restart s-ui >/dev/null 2>&1 &

fi

}


service_start(){

if [ "$OS" = "alpine" ]; then

    rc-service s-ui start >/dev/null 2>&1

else

    systemctl start s-ui >/dev/null 2>&1

fi

}



# ---------- 安装依赖 ----------

install_dependencies(){

echo "检测依赖..."

if [ "$OS" = "alpine" ]; then

    apk update >/dev/null 2>&1

    apk add \
    curl \
    wget \
    tar \
    gzip \
    unzip \
    ca-certificates \
    openssl \
    >/dev/null 2>&1


else


    apt-get update >/dev/null 2>&1


    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y \
    curl \
    wget \
    tar \
    gzip \
    unzip \
    ca-certificates \
    openssl \
    >/dev/null 2>&1


fi


}


# ---------- 保存配置 ----------

save_config(){

cat > "$CONFIG" <<EOF
OWNER=$OWNER
REPO=$REPO
INSTALL_PATH=$INSTALL_PATH
EOF

}



# ---------- 获取最新版本 ----------

get_latest(){

API="https://api.github.com/repos/$OWNER/$REPO/releases/latest"


VERSION=$(curl -fsL "$API" \
| grep '"tag_name"' \
| head -1 \
| sed 's/[^"]*"tag_name": *"//' \
| sed 's/".*//')


if [ -z "$VERSION" ]; then

    echo "latest"

else

    echo "$VERSION"

fi

}



# ---------- 下载 ----------

download_sui(){

mkdir -p "$TMP_DIR"

rm -rf "$TMP_DIR"/*


ARCH=$(uname -m)


case "$ARCH" in

x86_64)
ARCH="amd64"
;;

aarch64)
ARCH="arm64"
;;

armv7*)
ARCH="armv7"
;;

*)
ARCH="amd64"
;;

esac



VERSION=$(get_latest)


echo "下载版本: $VERSION"

URL="https://github.com/$OWNER/$REPO/releases/download/$VERSION/s-ui-linux-$ARCH.tar.gz"


echo "下载地址:"
echo "$URL"



TRY=0

while [ $TRY -lt 3 ]
do


curl \
-L \
--connect-timeout 10 \
--retry 2 \
-o "$TMP_DIR/s-ui.tar.gz" \
"$URL" && break


TRY=$((TRY+1))

sleep 2


done



if [ ! -f "$TMP_DIR/s-ui.tar.gz" ]; then

    red "下载失败"
    exit 1

fi


}



# ---------- 安装 ----------


install_sui(){


install_dependencies


download_sui



echo

read -p "安装版本(直接回车默认): " INPUT_VERSION


read -p "端口(默认2095): " PORT

[ -z "$PORT" ] && PORT=2095


read -p "用户名(默认admin): " USER

[ -z "$USER" ] && USER=admin


read -p "密码: " PASS



read -p "安装路径(默认$INSTALL_PATH): " NEWPATH


if [ -n "$NEWPATH" ]; then

INSTALL_PATH="$NEWPATH"

fi



mkdir -p "$INSTALL_PATH"



echo "解压..."



tar \
--no-same-owner \
--no-same-permissions \
-xzf "$TMP_DIR/s-ui.tar.gz" \
-C "$INSTALL_PATH"



chmod +x "$INSTALL_PATH/s-ui"



cat > "$INSTALL_PATH/config.txt" <<EOF
PORT=$PORT
USER=$USER
PASS=$PASS
EOF



save_config



create_service



echo

read -p "是否开机启动? (y/n): " BOOT


if [ "$BOOT" = "y" ]; then


if [ "$OS" = "alpine" ]; then

rc-update add s-ui default

else

systemctl enable s-ui

fi


fi



service_start


rm -rf "$TMP_DIR"


green "安装完成"


}



# ---------- 创建服务 ----------


create_service(){


if [ "$OS" = "alpine" ]; then


cat >/etc/init.d/s-ui <<EOF
#!/sbin/openrc-run

command="$INSTALL_PATH/s-ui"

command_background=true

pidfile="/run/s-ui.pid"


depend(){
need net
}


EOF


chmod +x /etc/init.d/s-ui



else


cat >/etc/systemd/system/s-ui.service <<EOF
[Unit]
Description=S-UI Service
After=network.target


[Service]
Type=simple
WorkingDirectory=$INSTALL_PATH
ExecStart=$INSTALL_PATH/s-ui
Restart=always
RestartSec=5


[Install]
WantedBy=multi-user.target
EOF



systemctl daemon-reload


fi


}



# ---------- 状态 ----------


show_status(){

if service_exists; then

green "S-UI 已安装"

echo "路径:"
echo "$INSTALL_PATH"


if [ "$OS" = "alpine" ]; then

rc-service s-ui status

else

systemctl status s-ui --no-pager

fi


else

yellow "S-UI 未安装"

fi

}
# ---------- 修改配置 ----------


modify_value(){

FILE="$INSTALL_PATH/config.txt"

if [ ! -f "$FILE" ]; then
    red "未找到配置文件"
    return
fi


case "$1" in

port)

read -p "输入新端口: " VALUE

sed -i "s/^PORT=.*/PORT=$VALUE/" "$FILE"

;;

user)

read -p "输入新用户名: " VALUE

sed -i "s/^USER=.*/USER=$VALUE/" "$FILE"

;;

pass)

read -p "输入新密码: " VALUE

sed -i "s/^PASS=.*/PASS=$VALUE/" "$FILE"

;;

esac


service_restart

green "修改完成"

}



# ---------- 修改安装路径 ----------


change_path(){

read -p "新的安装路径: " NEWPATH


if [ -z "$NEWPATH" ]; then
    return
fi


if [ ! -d "$INSTALL_PATH" ]; then
    red "原路径不存在"
    return
fi


mkdir -p "$NEWPATH"


echo "移动文件..."


cp -a "$INSTALL_PATH"/* "$NEWPATH"/


INSTALL_PATH="$NEWPATH"


save_config


create_service


service_restart


green "路径修改完成"

}



# ---------- 修改仓库 ----------


change_repo(){


echo

echo "当前仓库:"
echo "$OWNER/$REPO"


read -p "Github用户名: " NEWOWNER


read -p "Github仓库名: " NEWREPO



if [ -n "$NEWOWNER" ]; then

OWNER="$NEWOWNER"

fi


if [ -n "$NEWREPO" ]; then

REPO="$NEWREPO"

fi



save_config


green "仓库修改完成"

echo "$OWNER/$REPO"


}



# ---------- 升级 ----------


upgrade_sui(){


if ! service_exists; then

red "请先安装"

return

fi



echo "开始升级"


OLD_PATH="$INSTALL_PATH"


download_sui


mkdir -p "$TMP_DIR/new"


tar \
--no-same-owner \
--no-same-permissions \
-xzf "$TMP_DIR/s-ui.tar.gz" \
-C "$TMP_DIR/new"



if [ -f "$TMP_DIR/new/s-ui" ]; then


cp "$TMP_DIR/new/s-ui" "$OLD_PATH/s-ui"


chmod +x "$OLD_PATH/s-ui"


service_restart


green "升级完成"


else

red "升级失败"

fi



rm -rf "$TMP_DIR"

}



# ---------- 卸载 ----------


uninstall_sui(){


read -p "确认卸载 S-UI? (y/n): " OK


[ "$OK" != "y" ] && return



if [ "$OS" = "alpine" ]; then


rc-service s-ui stop >/dev/null 2>&1

rc-update del s-ui default >/dev/null 2>&1

rm -f /etc/init.d/s-ui


else


systemctl stop s-ui >/dev/null 2>&1

systemctl disable s-ui >/dev/null 2>&1

rm -f /etc/systemd/system/s-ui.service

systemctl daemon-reload


fi



rm -rf "$INSTALL_PATH"


rm -f "$CONFIG"



green "卸载完成"


}



# ---------- 显示当前配置 ----------


show_config(){


echo

echo "============"

echo "安装路径:"
echo "$INSTALL_PATH"


echo

echo "仓库:"
echo "$OWNER/$REPO"


if [ -f "$INSTALL_PATH/config.txt" ]; then

cat "$INSTALL_PATH/config.txt"

fi


echo "============"


}



# ---------- 菜单 ----------


menu(){


while true

do


clear


echo "================================"

echo "          S-UI 管理脚本"

echo "================================"



if service_exists; then

green "状态: 已安装"

else

yellow "状态: 未安装"

fi



echo

echo "1. 安装 S-UI"

echo "2. 卸载 S-UI"

echo "3. 升级 S-UI"

echo "4. 修改端口"

echo "5. 修改用户名"

echo "6. 修改密码"

echo "7. 修改安装路径"

echo "8. 查看状态"

echo "9. 修改安装仓库"

echo "10. 查看配置"

echo "0. 退出"


echo

read -p "请选择: " CHOICE



case "$CHOICE" in


1)

install_sui

;;


2)

uninstall_sui

;;


3)

upgrade_sui

;;


4)

modify_value port

;;


5)

modify_value user

;;


6)

modify_value pass

;;


7)

change_path

;;


8)

show_status

;;


9)

change_repo

;;


10)

show_config

;;


0)

exit 0

;;


*)

echo "错误选择"

;;

esac



echo

read -p "回车继续..."


done


}



# ---------- 启动 ----------


detect_os


save_config


menu
