#!/bin/sh
# s-ui-alpine-install.sh
# Alpine Linux 一键安装 S-UI，中文 + 北京时间 + 自定义端口路径

VERSION="1.3.10"
DOWNLOAD_URL="https://github.com/bulianglin/demo/releases/download/$VERSION/s-ui-linux-amd64.tar.gz"
INSTALL_DIR="/usr/local/s-ui"

echo "==== S-UI 一键安装脚本 (Alpine) ===="

# 1. 安装依赖
echo "安装基础依赖..."
apk add --no-cache bash curl tar tzdata coreutils

# 2. 设置时区为北京时间
TIMEZONE="Asia/Shanghai"
cp /usr/share/zoneinfo/$TIMEZONE /etc/localtime
echo "$TIMEZONE" > /etc/timezone
echo "时区已设置为 $TIMEZONE"

# 3. 设置中文语言环境
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export LC_ALL=zh_CN.UTF-8
echo "语言环境已设置为中文"

# 4. 创建安装目录
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# 5. 下载 S-UI
echo "下载 S-UI v$VERSION..."
curl -L -o s-ui-linux-amd64.tar.gz "$DOWNLOAD_URL"

# 6. 解压
echo "解压 S-UI..."
tar -xzf s-ui-linux-amd64.tar.gz
rm -f s-ui-linux-amd64.tar.gz

# 7. 交互式设置面板和订阅端口/路径
echo "请输入面板端口 (默认 51234):"
read PANEL_PORT
PANEL_PORT=${PANEL_PORT:-51234}

echo "请输入面板路径 (默认 /us/):"
read PANEL_PATH
PANEL_PATH=${PANEL_PATH:-/us/}
# 确保路径以 / 开头并以 / 结尾
[[ "$PANEL_PATH" != /* ]] && PANEL_PATH="/$PANEL_PATH"
[[ "$PANEL_PATH" != */ ]] && PANEL_PATH="$PANEL_PATH/"

echo "请输入订阅端口 (默认 51111):"
read SUB_PORT
SUB_PORT=${SUB_PORT:-51111}

echo "请输入订阅路径 (默认 /ussub/):"
read SUB_PATH
SUB_PATH=${SUB_PATH:-/ussub/}
[[ "$SUB_PATH" != /* ]] && SUB_PATH="/$SUB_PATH"
[[ "$SUB_PATH" != */ ]] && SUB_PATH="$SUB_PATH/"

# 8. 设置管理员账号
echo "请输入管理员用户名 (默认 faxone):"
read ADMIN_USER
ADMIN_USER=${ADMIN_USER:-faxone}

echo "请输入管理员密码 (默认 1234qweasd.):"
read ADMIN_PASS
ADMIN_PASS=${ADMIN_PASS:-1234qweasd.}

# 保存配置
cat > "$INSTALL_DIR/s-ui_config.cfg" <<EOF
PANEL_PORT=$PANEL_PORT
PANEL_PATH=$PANEL_PATH
SUB_PORT=$SUB_PORT
SUB_PATH=$SUB_PATH
ADMIN_USER=$ADMIN_USER
ADMIN_PASS=$ADMIN_PASS
EOF

# 9. 创建启动脚本
cat > "$INSTALL_DIR/s-ui-start.sh" <<'EOF'
#!/bin/sh
SUI_PATH="$(dirname "$0")"
SUI_BIN="$SUI_PATH/sui"
SUI_LOG="$SUI_PATH/s-ui.log"
PID_FILE="$SUI_PATH/s-ui.pid"

start() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo "S-UI 已经在运行"
        exit 0
    fi
    echo "启动 S-UI ..."
    nohup "$SUI_BIN" > "$SUI_LOG" 2>&1 &
    echo $! > "$PID_FILE"
    echo "启动完成，日志在 $SUI_LOG"
}

stop() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo "停止 S-UI ..."
        kill $(cat "$PID_FILE")
        rm -f "$PID_FILE"
        echo "已停止"
    else
        echo "S-UI 没有运行"
    fi
}

status() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo "S-UI 正在运行，PID: $(cat "$PID_FILE")"
    else
        echo "S-UI 没有运行"
    fi
}

log() {
    tail -f "$SUI_LOG"
}

case "$1" in
    start) start ;;
    stop) stop ;;
    restart) stop; start ;;
    status) status ;;
    log) log ;;
    *) echo "用法: $0 {start|stop|restart|status|log}"; exit 1 ;;
esac
EOF

chmod +x "$INSTALL_DIR/s-ui-start.sh"

# 10. 启动 S-UI
"$INSTALL_DIR/s-ui-start.sh" start

echo "==== 安装完成 ===="
echo "访问面板 URL: http://<服务器IP>:$PANEL_PORT$PANEL_PATH"
echo "管理员账号: $ADMIN_USER / $ADMIN_PASS"
echo "可用命令: $INSTALL_DIR/s-ui-start.sh {start|stop|restart|status|log}"