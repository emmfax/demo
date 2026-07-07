
#!/bin/sh
#
# s-ui lightweight installer manager
# Debian / Alpine compatible
#

VERSION="1.0"

# =====================
# 默认仓库
# =====================

SUI_REPO_USER="alireza0"
SUI_REPO_NAME="s-ui"

SUI_DIR="/usr/local/s-ui"

CONFIG_FILE="/etc/s-ui.conf"


# =====================
# 颜色
# =====================

red="\033[31m"
green="\033[32m"
yellow="\033[33m"
reset="\033[0m"


msg(){
    echo -e "${green}$1${reset}"
}

warn(){
    echo -e "${yellow}$1${reset}"
}


# =====================
# root检测
# =====================

if [ "$(id -u)" != "0" ]; then
    echo "请使用root运行"
    exit 1
fi


# =====================
# 系统检测
# =====================

check_os(){

    if [ -f /etc/alpine-release ]; then
        OS="alpine"
    elif [ -f /etc/debian_version ]; then
        OS="debian"
    else
        echo "不支持当前系统"
        exit 1
    fi
}


# =====================
# 安装依赖
# =====================

install_dep(){

    msg "检测s-ui依赖..."

    if command -v curl >/dev/null 2>&1; then
        return
    fi

    if [ "$OS" = "alpine" ]; then

        apk update >/dev/null 2>&1
        apk add --no-cache curl wget tar unzip ca-certificates >/dev/null 2>&1

    else

        apt-get update >/dev/null 2>&1
        DEBIAN_FRONTEND=noninteractive apt-get install -y \
        curl wget tar unzip ca-certificates >/dev/null 2>&1

    fi
}



# =====================
# s-ui检测
# =====================

check_sui(){

    if [ -f "$SUI_DIR/sui" ] || \
       [ -f "/usr/local/bin/sui" ]; then

        return 0

    fi

    return 1
}



# =====================
# 读取配置
# =====================

load_config(){

    if [ -f "$CONFIG_FILE" ]; then

        . "$CONFIG_FILE"

    fi

}


save_config(){

cat > "$CONFIG_FILE" <<EOF
SUI_DIR="$SUI_DIR"
SUI_PORT="$SUI_PORT"
SUI_USER="$SUI_USER"
SUI_PASS="$SUI_PASS"
EOF

}



# =====================
# GitHub下载
# =====================

download_sui(){

    mkdir -p "$SUI_DIR"

    TMP="/tmp/s-ui-install"

    rm -rf "$TMP"

    mkdir "$TMP"


    URL="https://github.com/${SUI_REPO_USER}/${SUI_REPO_NAME}/releases/latest"


    msg "下载s-ui..."


    cd "$TMP" || exit


    if command -v wget >/dev/null; then

        wget -q "$URL" -O page.html

    else

        curl -Ls "$URL" -o page.html

    fi


    # 使用官方安装脚本

    SCRIPT="https://raw.githubusercontent.com/${SUI_REPO_USER}/${SUI_REPO_NAME}/main/install.sh"


    if curl -Ls "$SCRIPT" -o install.sh; then

        chmod +x install.sh

        SUI_INSTALL_DIR="$SUI_DIR" \
        bash install.sh

    else

        echo "无法获取安装脚本"
        exit 1

    fi

}



# =====================
# 安装
# =====================

install_sui(){

    if check_sui; then
        warn "s-ui已经安装"
        return
    fi


    install_dep


    echo
    read -p "版本(直接回车最新版): " ver

    read -p "端口: " SUI_PORT

    [ -z "$SUI_PORT" ] && SUI_PORT="2095"


    read -p "用户名: " SUI_USER

    [ -z "$SUI_USER" ] && SUI_USER="admin"


    read -p "密码: " SUI_PASS

    [ -z "$SUI_PASS" ] && SUI_PASS="admin"



    read -p "安装路径 [$SUI_DIR]: " path

    [ -n "$path" ] && SUI_DIR="$path"



    save_config


    download_sui



    msg "安装完成"



    read -p "是否设置开机启动(y/n): " boot


    if [ "$boot" = "y" ]; then

        enable_start

    fi

}



# =====================
# 启动管理
# =====================

enable_start(){

    if command -v systemctl >/dev/null 2>&1; then

        systemctl enable sui >/dev/null 2>&1

    elif [ -d /etc/local.d ]; then

        cat >/etc/local.d/sui.start <<EOF
#!/bin/sh
$SUI_DIR/sui >/dev/null 2>&1 &
EOF

        chmod +x /etc/local.d/sui.start

        rc-update add local >/dev/null 2>&1

    else

        echo "@reboot $SUI_DIR/sui" >/etc/crontabs/root

    fi

}


# =====================
# 卸载
# =====================

uninstall_sui(){

    if ! check_sui; then
        warn "没有检测到s-ui"
        return
    fi


    read -p "确认卸载? y/n: " c


    [ "$c" != "y" ] && return


    rm -rf "$SUI_DIR"

    rm -f "$CONFIG_FILE"


    msg "卸载完成"

}



# =====================
# 升级
# =====================

upgrade_sui(){

    if ! check_sui; then

        warn "未安装"

        return

    fi


    install_dep

    download_sui

    msg "升级完成"

}



# =====================
# 状态
# =====================

status_sui(){

    if check_sui; then

        echo "s-ui 已安装"

    else

        echo "s-ui 未安装"

    fi


    if pgrep sui >/dev/null; then

        echo "运行状态:运行"

    else

        echo "运行状态:停止"

    fi

}



# =====================
# 修改参数
# =====================

change_port(){

load_config

read -p "新端口:" SUI_PORT

save_config

echo "请重启s-ui生效"

}


change_user(){

load_config

read -p "新用户名:" SUI_USER

save_config

}



change_pass(){

load_config

read -p "新密码:" SUI_PASS

save_config

}



change_path(){

read -p "新路径:" new

[ -z "$new" ] && return


mv "$SUI_DIR" "$new"

SUI_DIR="$new"

save_config

}



# =====================
# 修改仓库
# =====================

change_repo(){

echo "当前:"
echo "$SUI_REPO_USER/$SUI_REPO_NAME"


read -p "Github用户名:" SUI_REPO_USER

read -p "仓库名:" SUI_REPO_NAME


echo "修改完成"

}



# =====================
# 菜单
# =====================

menu(){

while true
do

clear

echo "======================"
echo " s-ui管理脚本 $VERSION"
echo "======================"

if check_sui; then

echo "状态: 已安装"

else

echo "状态: 未安装"

fi


echo
echo "1.安装s-ui"
echo "2.卸载s-ui"
echo "3.升级s-ui"
echo "4.修改端口"
echo "5.修改用户名"
echo "6.修改密码"
echo "7.修改安装路径"
echo "8.查看状态"
echo "9.修改安装仓库"
echo "0.退出"

echo

read -p "选择:" n


case $n in

1) install_sui;;

2) uninstall_sui;;

3) upgrade_sui;;

4) change_port;;

5) change_user;;

6) change_pass;;

7) change_path;;

8) status_sui;;

9) change_repo;;

0) exit;;

*) echo "错误";;

esac


echo
read -p "回车继续..."

done

}



check_os

load_config

menu
