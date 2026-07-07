#!/bin/sh

# s-ui lightweight manager
# Alpine / Debian optimized

VERSION="1.0"

BASE_DIR="/usr/local/s-ui"
BIN_LINK="/usr/local/bin/suio"
SCRIPT_PATH="/usr/local/bin/sui.sh"

DEFAULT_REPO="alireza0/s-ui"

SUI_REPO="$DEFAULT_REPO"


red(){
    printf "\033[31m%s\033[0m\n" "$1"
}

green(){
    printf "\033[32m%s\033[0m\n" "$1"
}

yellow(){
    printf "\033[33m%s\033[0m\n" "$1"
}


pause(){
    printf "\n按回车继续..."
    read _
}


clear_cache(){

    rm -rf /tmp/*sui* 2>/dev/null
    rm -rf /tmp/*.tar.gz 2>/dev/null

}



check_root(){

    if [ "$(id -u)" != "0" ]; then
        red "请使用root运行"
        exit 1
    fi

}



detect_sui(){

    if [ -f "/usr/local/s-ui/s-ui" ] ||
       [ -f "/usr/bin/s-ui" ] ||
       command -v s-ui >/dev/null 2>&1
    then
        echo "yes"
    else
        echo "no"
    fi

}



detect_system(){

    if command -v apk >/dev/null 2>&1
    then
        OS="alpine"
    elif command -v apt >/dev/null 2>&1
    then
        OS="debian"
    else
        OS="unknown"
    fi

}



install_dep(){

echo "检测依赖..."

if [ "$OS" = "alpine" ]; then

    apk update >/dev/null 2>&1

    apk add \
    curl \
    wget \
    tar \
    gzip \
    bash \
    ca-certificates \
    jq \
    unzip >/dev/null 2>&1


elif [ "$OS" = "debian" ]; then


    apt update >/dev/null 2>&1

    DEBIAN_FRONTEND=noninteractive apt install -y \
    curl \
    wget \
    tar \
    gzip \
    bash \
    ca-certificates \
    jq \
    unzip >/dev/null 2>&1


fi

}



get_repo(){

    echo "$SUI_REPO"

}



parse_repo(){

url="$1"

url=$(echo "$url" | sed 's#https://github.com/##')

url=$(echo "$url" | sed 's#/$##')

SUI_REPO="$url"

}



show_repo(){

echo

echo "当前仓库:"
echo "$SUI_REPO"

}



download_release(){


repo=$(get_repo)


echo "获取版本..."

api="https://api.github.com/repos/$repo/releases"


VERSIONS=$(curl -fsSL "$api" \
| jq -r '.[].tag_name' 2>/dev/null)


if [ -z "$VERSIONS" ]; then

    red "无法获取版本"
    return 1

fi


echo

echo "可用版本:"

i=1

for v in $VERSIONS
do

echo "$i) $v"

eval "ver$i=$v"

i=$((i+1))

done


echo

printf "选择版本:"
read num


VERSION_SELECT=$(eval echo \$ver$num)


if [ -z "$VERSION_SELECT" ]; then

red "选择错误"
return 1

fi


echo

echo "选择:"
echo "$VERSION_SELECT"



}



arch_detect(){


ARCH=$(uname -m)


case "$ARCH" in

x86_64)
ARCH="amd64"
;;

aarch64)
ARCH="arm64"
;;

armv7*)
ARCH="arm"
;;

*)
ARCH="amd64"
;;

esac


}


install_sui(){

clear_cache

install_dep

arch_detect

download_release || return


mkdir -p "$BASE_DIR"


echo
echo "请输入安装路径"
printf "默认 [%s]: " "$BASE_DIR"
read input

if [ -n "$input" ]; then
    BASE_DIR="$input"
fi


echo
echo "开始下载..."

repo=$(get_repo)


# 获取下载地址
URL=$(curl -fsSL \
"https://api.github.com/repos/$repo/releases/tags/$VERSION_SELECT" \
| jq -r '.assets[].browser_download_url' \
| grep -Ei "$ARCH|linux" \
| head -n 1)


if [ -z "$URL" ]; then

    red "未找到对应架构文件"

    return 1

fi


echo

echo "下载:"
echo "$URL"

TMP="/tmp/s-ui.tar.gz"


rm -f "$TMP"


curl -L \
--progress-bar \
-o "$TMP" \
"$URL"



if [ ! -s "$TMP" ]; then

    red "下载失败"

    return 1

fi



echo

echo "解压中..."



# 低内存解压
tar \
--no-same-owner \
-xzf "$TMP" \
-C "$BASE_DIR" 2>/dev/null



if [ $? != 0 ]; then

    red "解压失败"

    return 1

fi



rm -f "$TMP"



chmod +x "$BASE_DIR"/s-ui* 2>/dev/null



echo

echo "设置账号"



printf "管理端口:"
read PORT


[ -z "$PORT" ] && PORT="2095"



printf "用户名:"
read USER


[ -z "$USER" ] && USER="admin"



printf "密码:"
read PASS


[ -z "$PASS" ] && PASS="admin"



echo


create_config



create_service



green "安装完成"



printf "是否开机启动?(y/n): "

read boot


case "$boot" in

y|Y)

enable_service

;;

esac



}



create_config(){


CONF="$BASE_DIR/config.json"


if [ ! -f "$CONF" ]; then


cat > "$CONF" <<EOF
{
"port":"$PORT",
"username":"$USER",
"password":"$PASS"
}
EOF


fi


}



create_service(){


if [ "$OS" = "debian" ]; then


cat > /etc/systemd/system/s-ui.service <<EOF
[Unit]
Description=s-ui
After=network.target

[Service]
Type=simple
WorkingDirectory=$BASE_DIR
ExecStart=$BASE_DIR/s-ui
Restart=always

[Install]
WantedBy=multi-user.target
EOF


systemctl daemon-reload



elif [ "$OS" = "alpine" ]; then



cat > /etc/init.d/s-ui <<EOF
#!/sbin/openrc-run

name="s-ui"

command="$BASE_DIR/s-ui"

command_background="yes"

pidfile="/run/s-ui.pid"

EOF


chmod +x /etc/init.d/s-ui


fi



}



enable_service(){


if [ "$OS" = "debian" ]; then

systemctl enable s-ui >/dev/null 2>&1
systemctl restart s-ui


elif [ "$OS" = "alpine" ]; then

rc-update add s-ui default >/dev/null 2>&1
rc-service s-ui restart


fi


}



start_service(){


if [ "$OS" = "debian" ]; then

systemctl start s-ui


else

rc-service s-ui start


fi


}



stop_service(){


if [ "$OS" = "debian" ]; then

systemctl stop s-ui


else

rc-service s-ui stop


fi


}



restart_service(){


if [ "$OS" = "debian" ]; then

systemctl restart s-ui


else

rc-service s-ui restart


fi


}



status_service(){


if [ "$OS" = "debian" ]; then

systemctl status s-ui --no-pager


else

rc-service s-ui status


fi


}



uninstall_sui(){


echo

printf "确认卸载?(y/n): "

read c


case "$c" in

y|Y)


stop_service


if [ "$OS" = "debian" ]; then

systemctl disable s-ui >/dev/null 2>&1
rm -f /etc/systemd/system/s-ui.service
systemctl daemon-reload


else

rc-update del s-ui default >/dev/null 2>&1
rm -f /etc/init.d/s-ui


fi



rm -rf "$BASE_DIR"


green "已卸载"


;;

esac


}


upgrade_sui(){

echo "升级 s-ui"

download_release || return


echo "下载新版..."

repo=$(get_repo)


URL=$(curl -fsSL \
"https://api.github.com/repos/$repo/releases/tags/$VERSION_SELECT" \
| jq -r '.assets[].browser_download_url' \
| grep -Ei "$ARCH|linux" \
| head -n 1)


if [ -z "$URL" ]; then

red "没有找到下载文件"

return

fi


TMP="/tmp/s-ui-upgrade.tar.gz"


rm -f "$TMP"


curl -L \
--progress-bar \
-o "$TMP" \
"$URL"



if [ ! -s "$TMP" ]; then

red "下载失败"

return

fi



stop_service



echo "替换文件..."

tar \
--no-same-owner \
-xzf "$TMP" \
-C "$BASE_DIR"



rm -f "$TMP"


chmod +x "$BASE_DIR"/s-ui* 2>/dev/null


start_service


green "升级完成"


}




modify_value(){


CONF="$BASE_DIR/config.json"


if [ ! -f "$CONF" ]; then

red "没有找到配置文件"

return

fi


}



modify_port(){


printf "新端口:"
read NEW


sed -i \
"s/\"port\":\"[^\"]*\"/\"port\":\"$NEW\"/" \
"$BASE_DIR/config.json"


restart_service


green "端口修改完成"


}



modify_user(){


printf "新用户名:"
read NEW


sed -i \
"s/\"username\":\"[^\"]*\"/\"username\":\"$NEW\"/" \
"$BASE_DIR/config.json"


restart_service


green "用户名修改完成"


}



modify_pass(){


printf "新密码:"
read NEW


sed -i \
"s/\"password\":\"[^\"]*\"/\"password\":\"$NEW\"/" \
"$BASE_DIR/config.json"


restart_service


green "密码修改完成"


}




modify_path(){


printf "新路径:"
read NEW


if [ -z "$NEW" ]; then
return
fi


stop_service


mv "$BASE_DIR" "$NEW"


BASE_DIR="$NEW"


sed -i \
"s#WorkingDirectory=.*#WorkingDirectory=$BASE_DIR#" \
/etc/systemd/system/s-ui.service 2>/dev/null



sed -i \
"s#ExecStart=.*#ExecStart=$BASE_DIR/s-ui#" \
/etc/systemd/system/s-ui.service 2>/dev/null



systemctl daemon-reload 2>/dev/null



start_service



green "路径修改完成"



}




change_repo(){


echo

echo "当前仓库:"
echo "$SUI_REPO"


echo

echo "输入GitHub仓库地址"

echo "例如:"
echo "https://github.com/alireza0/s-ui"


printf "> "

read URL


if [ -n "$URL" ]; then


parse_repo "$URL"


sed -i \
"s#^SUI_REPO=.*#SUI_REPO=\"$SUI_REPO\"#" \
"$SCRIPT_PATH"


green "仓库修改完成"


fi



}




install_shortcut(){


cp "$0" "$SCRIPT_PATH"


cat > "$BIN_LINK" <<EOF
#!/bin/sh
bash $SCRIPT_PATH
EOF


chmod +x "$BIN_LINK"



}




remove_script(){


echo

printf "删除管理脚本和快捷命令?(y/n): "

read c


case "$c" in

y|Y)

rm -f "$BIN_LINK"
rm -f "$SCRIPT_PATH"

green "删除完成"

;;

esac



}



menu(){


while true

do


clear


echo "======================"

echo " s-ui 管理脚本"

echo "======================"


if [ "$(detect_sui)" = "yes" ]; then

green "状态: 已安装"

else

yellow "状态: 未安装"

fi


echo

echo "仓库:"
echo "$SUI_REPO"


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

echo "10. 删除脚本和快捷命令"

echo "0. 退出"


echo

printf "选择: "

read choice



case "$choice" in


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

modify_port
pause

;;


5)

modify_user
pause

;;


6)

modify_pass
pause

;;


7)

modify_path
pause

;;


8)

status_service
pause

;;


9)

change_repo
pause

;;


10)

remove_script
exit

;;


0)

exit

;;


*)

echo "错误"

;;

esac


done


}



main(){


check_root


detect_system


if [ "$OS" = "unknown" ]; then

red "不支持当前系统"

exit

fi



install_shortcut


menu



}



main
