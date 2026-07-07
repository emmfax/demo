#!/bin/sh

# ==========================================================
# s-ui 极简安装管理脚本
# 支持 Debian / Ubuntu / Alpine
# 适合 64MB-512MB 小型容器
# ==========================================================

export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export TERM=xterm

trap '' HUP

APP_NAME="s-ui"

# 默认仓库
GITHUB_USER="alireza0"
GITHUB_REPO="s-ui"

# 默认路径
INSTALL_PATH="/opt/s-ui"

CONFIG_FILE="/etc/s-ui.conf"

LOG_FILE="/tmp/s-ui-install.log"

VERSION=""

# ----------------------------------------------------------
# 输出
# ----------------------------------------------------------

info()
{
    echo "[信息] $1"
}

ok()
{
    echo "[完成] $1"
}

err()
{
    echo "[错误] $1"
}

pause()
{
    printf "\n按回车继续..."
    read x
}


# ----------------------------------------------------------
# root检测
# ----------------------------------------------------------

check_root()
{
    if [ "$(id -u)" != "0" ]; then
        err "请使用root运行"
        exit 1
    fi
}


# ----------------------------------------------------------
# 系统检测
# ----------------------------------------------------------

detect_os()
{
    if [ -f /etc/alpine-release ]; then
        OS="alpine"
    elif [ -f /etc/debian_version ]; then
        OS="debian"
    else
        err "不支持当前系统"
        exit 1
    fi
}


# ----------------------------------------------------------
# 安装依赖
# ----------------------------------------------------------

install_dep()
{
    info "检测依赖"

    NEED=""

    for i in curl wget tar gzip ca-certificates
    do
        if ! command -v $i >/dev/null 2>&1
        then
            NEED="$NEED $i"
        fi
    done


    if [ -z "$NEED" ]
    then
        ok "依赖完整"
        return
    fi


    info "安装:$NEED"


    if [ "$OS" = "alpine" ]
    then

        apk update >/dev/null 2>&1
        apk add --no-cache $NEED

    else

        export DEBIAN_FRONTEND=noninteractive

        apt-get update -y >/dev/null 2>&1

        apt-get install -y $NEED

    fi

}


# ----------------------------------------------------------
# 保存配置
# ----------------------------------------------------------

save_config()
{
cat > "$CONFIG_FILE" <<EOF
GITHUB_USER="$GITHUB_USER"
GITHUB_REPO="$GITHUB_REPO"
INSTALL_PATH="$INSTALL_PATH"
EOF
}


# ----------------------------------------------------------
# 读取配置
# ----------------------------------------------------------

load_config()
{
    if [ -f "$CONFIG_FILE" ]
    then
        . "$CONFIG_FILE"
    fi
}


# ----------------------------------------------------------
# 检测s-ui
# ----------------------------------------------------------

check_sui()
{

    if [ -x "$INSTALL_PATH/s-ui" ]
    then
        SUI_INSTALLED=1
    else
        SUI_INSTALLED=0
    fi

}


# ----------------------------------------------------------
# 获取最新版本
# ----------------------------------------------------------

get_latest()
{

    info "获取版本信息"


    URL="https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/releases/latest"


    VERSION=$(curl -fsSL "$URL" 2>/dev/null \
    | grep '"tag_name"' \
    | head -1 \
    | sed 's/.*"tag_name": "\(.*\)",/\1/')


    if [ -z "$VERSION" ]
    then
        err "无法获取版本"
        return 1
    fi


    echo "$VERSION"

}


# ----------------------------------------------------------
# 下载
# ----------------------------------------------------------

download_sui()
{

    VERSION="$1"


    mkdir -p /tmp/s-ui-download


    FILE="/tmp/s-ui-download/s-ui.tar.gz"


    URL="https://github.com/$GITHUB_USER/$GITHUB_REPO/releases/download/$VERSION/s-ui-$VERSION-linux-amd64.tar.gz"


    info "下载:"
    echo "$URL"


    rm -f "$FILE"


    wget \
    --timeout=30 \
    --tries=3 \
    --continue \
    -O "$FILE" \
    "$URL" >>"$LOG_FILE" 2>&1



    if [ $? != 0 ]
    then
        err "下载失败"
        return 1
    fi


    ok "下载完成"

}



# ----------------------------------------------------------
# 解压安装
# ----------------------------------------------------------

extract_install()
{

    mkdir -p "$INSTALL_PATH"


    info "解压"


    tar \
    --no-same-owner \
    -xzf \
    /tmp/s-ui-download/s-ui.tar.gz \
    -C "$INSTALL_PATH"


    if [ $? != 0 ]
    then
        err "解压失败"
        return 1
    fi


    chmod +x "$INSTALL_PATH/s-ui" 2>/dev/null


    rm -rf /tmp/s-ui-download


    ok "安装文件完成"

}

# ----------------------------------------------------------
# 创建服务
# ----------------------------------------------------------

create_service()
{

if [ "$OS" = "debian" ]
then

cat >/etc/systemd/system/s-ui.service <<EOF
[Unit]
Description=s-ui
After=network.target

[Service]
Type=simple
WorkingDirectory=$INSTALL_PATH
ExecStart=$INSTALL_PATH/s-ui
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF


systemctl daemon-reload


else


cat >/etc/init.d/s-ui <<EOF
#!/sbin/openrc-run

name="s-ui"
command="$INSTALL_PATH/s-ui"
command_background="yes"
pidfile="/run/s-ui.pid"

depend()
{
    need net
}
EOF


chmod +x /etc/init.d/s-ui


fi


}


# ----------------------------------------------------------
# 启动服务
# ----------------------------------------------------------

start_service()
{

if [ "$OS" = "debian" ]
then

    systemctl restart s-ui >/dev/null 2>&1

else

    rc-service s-ui restart >/dev/null 2>&1

fi

}



# ----------------------------------------------------------
# 开机启动
# ----------------------------------------------------------

enable_service()
{

echo
printf "是否设置开机启动? (y/n): "
read boot


case "$boot" in

y|Y)

if [ "$OS" = "debian" ]
then

systemctl enable s-ui

else

rc-update add s-ui default

fi

ok "已开启开机启动"

;;

*)

info "跳过开机启动"

;;

esac

}



# ----------------------------------------------------------
# 安装
# ----------------------------------------------------------

install_sui()
{

check_sui


if [ "$SUI_INSTALLED" = "1" ]
then

echo "s-ui已经安装"

return

fi


install_dep


get_latest


if [ -z "$VERSION" ]
then
return
fi


echo
echo "当前版本:$VERSION"


printf "请输入安装版本(直接回车使用当前): "
read INPUT_VERSION


if [ -n "$INPUT_VERSION" ]
then

VERSION="$INPUT_VERSION"

fi



printf "请输入安装路径 [%s]: " "$INSTALL_PATH"
read INPUT_PATH


if [ -n "$INPUT_PATH" ]
then

INSTALL_PATH="$INPUT_PATH"

fi



printf "请输入端口:"
read SUI_PORT


printf "请输入用户名:"
read SUI_USER


printf "请输入密码:"
read SUI_PASS



save_config


download_sui "$VERSION"


extract_install


create_service


start_service



echo
ok "s-ui安装完成"


echo
echo "路径:$INSTALL_PATH"
echo "端口:$SUI_PORT"
echo "用户名:$SUI_USER"


enable_service


}



# ----------------------------------------------------------
# 卸载
# ----------------------------------------------------------

uninstall_sui()
{

check_sui


if [ "$SUI_INSTALLED" != "1" ]
then

echo "未安装s-ui"

return

fi


printf "确认卸载? (y/n): "
read confirm


case "$confirm" in

y|Y)


if [ "$OS" = "debian" ]
then

systemctl stop s-ui 2>/dev/null
systemctl disable s-ui 2>/dev/null
rm -f /etc/systemd/system/s-ui.service
systemctl daemon-reload

else

rc-service s-ui stop 2>/dev/null
rc-update del s-ui default 2>/dev/null
rm -f /etc/init.d/s-ui

fi



rm -rf "$INSTALL_PATH"


ok "卸载完成"


;;


*)

echo "取消"

;;

esac


}



# ----------------------------------------------------------
# 升级
# ----------------------------------------------------------

upgrade_sui()
{


check_sui


if [ "$SUI_INSTALLED" != "1" ]
then

echo "请先安装"

return

fi



install_dep


get_latest


download_sui "$VERSION"


systemctl stop s-ui 2>/dev/null


extract_install


start_service


ok "升级完成"


}



# ----------------------------------------------------------
# 状态
# ----------------------------------------------------------

status_sui()
{


check_sui


echo
echo "========== s-ui状态 =========="


if [ "$SUI_INSTALLED" = "1" ]
then

echo "安装状态: 已安装"
echo "路径: $INSTALL_PATH"
echo "版本:"
"$INSTALL_PATH/s-ui" version 2>/dev/null || echo "未知"



if [ "$OS" = "debian" ]
then

systemctl status s-ui --no-pager 2>/dev/null

else

rc-service s-ui status 2>/dev/null

fi



else

echo "安装状态: 未安装"

fi


echo "=============================="


}


# ----------------------------------------------------------
# 修改端口
# ----------------------------------------------------------

change_port()
{

check_sui

if [ "$SUI_INSTALLED" != "1" ]
then
echo "未安装s-ui"
return
fi


printf "请输入新端口:"
read NEW_PORT


if [ -z "$NEW_PORT" ]
then
return
fi


# 尝试修改常见配置
if [ -f "$INSTALL_PATH/config.json" ]
then

sed -i "s/\"port\"[[:space:]]*:[[:space:]]*[0-9]*/\"port\":$NEW_PORT/" \
"$INSTALL_PATH/config.json"

fi


if [ -f "$INSTALL_PATH/db/s-ui.db" ]
then
echo "检测到数据库，请使用s-ui面板修改"
fi


start_service


ok "端口修改完成"

}



# ----------------------------------------------------------
# 修改用户名
# ----------------------------------------------------------

change_user()
{

check_sui

if [ "$SUI_INSTALLED" != "1" ]
then
echo "未安装s-ui"
return
fi


printf "请输入新用户名:"
read NEW_USER


if [ -z "$NEW_USER" ]
then
return
fi


echo
echo "用户名修改需要通过s-ui数据库完成"
echo "如果新版支持配置文件，将自动修改"


if [ -f "$INSTALL_PATH/config.json" ]
then

sed -i "s/\"username\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"username\":\"$NEW_USER\"/" \
"$INSTALL_PATH/config.json"

fi


start_service


}



# ----------------------------------------------------------
# 修改密码
# ----------------------------------------------------------

change_pass()
{

check_sui

if [ "$SUI_INSTALLED" != "1" ]
then
echo "未安装s-ui"
return
fi


printf "请输入新密码:"
read NEW_PASS


if [ -z "$NEW_PASS" ]
then
return
fi


echo
echo "密码修改需要数据库支持"


}



# ----------------------------------------------------------
# 修改路径
# ----------------------------------------------------------

change_path()
{

check_sui

if [ "$SUI_INSTALLED" != "1" ]
then
echo "未安装s-ui"
return
fi


printf "请输入新路径:"
read NEW_PATH


if [ -z "$NEW_PATH" ]
then
return
fi


systemctl stop s-ui 2>/dev/null


mkdir -p "$NEW_PATH"


cp -a "$INSTALL_PATH/"* "$NEW_PATH/"


OLD="$INSTALL_PATH"

INSTALL_PATH="$NEW_PATH"


sed -i "s#$OLD#$NEW_PATH#g" /etc/systemd/system/s-ui.service 2>/dev/null


save_config


create_service


start_service


ok "路径修改完成"

}




# ----------------------------------------------------------
# 修改仓库
# ----------------------------------------------------------

change_repo()
{

echo
echo "当前仓库:"
echo "$GITHUB_USER/$GITHUB_REPO"


printf "GitHub用户名:"
read NEW_OWNER


printf "GitHub仓库:"
read NEW_REPO



if [ -n "$NEW_OWNER" ]
then

GITHUB_USER="$NEW_OWNER"

fi


if [ -n "$NEW_REPO" ]
then

GITHUB_REPO="$NEW_REPO"

fi


save_config


ok "仓库修改完成"

echo "当前:"
echo "$GITHUB_USER/$GITHUB_REPO"

}




# ----------------------------------------------------------
# 主菜单
# ----------------------------------------------------------

menu()
{

while true
do


load_config

check_sui


clear


echo "================================="
echo "       s-ui 极简管理脚本"
echo "================================="


if [ "$SUI_INSTALLED" = "1" ]
then

echo "s-ui状态: 已安装"

else

echo "s-ui状态: 未安装"

fi


echo
echo "1. 安装 s-ui"
echo "2. 卸载 s-ui"
echo "3. 升级 s-ui"
echo "4. 修改端口"
echo "5. 修改用户名"
echo "6. 修改密码"
echo "7. 修改安装路径"
echo "8. 查看状态"
echo "9. 修改安装仓库"
echo "0. 退出"

echo
printf "请选择:"
read CHOICE


case "$CHOICE" in

1)
install_sui
pause
;;

2)
uninstall_sui
pause
;;

3)
upgrade_sui
pause
;;

4)
change_port
pause
;;

5)
change_user
pause
;;

6)
change_pass
pause
;;

7)
change_path
pause
;;

8)
status_sui
pause
;;

9)
change_repo
pause
;;

0)

exit 0

;;

*)

echo "错误选择"
sleep 1

;;

esac


done

}



# ----------------------------------------------------------
# 入口
# ----------------------------------------------------------

check_root

detect_os

load_config

menu
