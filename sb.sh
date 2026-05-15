#!/bin/sh
# Alpine Linux 一键 S-UI 后置启动脚本（北京时间 Asia/Shanghai）

INSTALL_DIR="/usr/local/s-ui"
LOG_FILE="/var/log/s-ui.log"
TIMEZONE="Asia/Shanghai"  # 默认北京时间

echo "Step 1: 安装必要依赖..."
apk update
apk add bash socat curl tar coreutils openrc tzdata

echo "Step 2: 设置系统时区为北京时间..."
cp /usr/share/zoneinfo/$TIMEZONE /etc/localtime
echo "$TIMEZONE" > /etc/timezone
export TZ="$TIMEZONE"

echo "Step 3: 确保安装目录存在..."
mkdir -p "$INSTALL_DIR"

echo "Step 4: 创建 OpenRC 服务..."
cat <<'EOF' > /etc/init.d/s-ui
#!/sbin/openrc-run
# Alpine OpenRC service for S-UI

name="s-ui"
description="S-UI Panel Service"
command="/usr/local/s-ui/sui"
command_args=""
pidfile="/run/s-ui.pid"

depend() {
    need net
}

start_pre() {
    checkpath --directory --mode 0755 /run
}

start() {
    ebegin "Starting S-UI"
    # nohup 后台启动，日志写入 /var/log/s-ui.log，并指定北京时间 TZ
    nohup env TZ="Asia/Shanghai" "$command" > /var/log/s-ui.log 2>&1 &
    echo $! > "$pidfile"
    eend 0
}

stop() {
    ebegin "Stopping S-UI"
    if [ -f "$pidfile" ]; then
        kill $(cat "$pidfile") 2>/dev/null
        rm -f "$pidfile"
    fi
    eend 0
}
EOF

chmod +x /etc/init.d/s-ui
rc-update add s-ui default

echo "Step 5: 启动 S-UI 服务..."
rc-service s-ui restart

echo "Step 6: 检查 S-UI 状态..."
if pgrep -f sui >/dev/null; then
    echo "S-UI 已经在运行！"
    echo "日志文件：$LOG_FILE"
else
    echo "S-UI 启动失败！请检查日志：$LOG_FILE"
fi

echo "安装完成。开机自启已配置。"
echo "查看面板 URL：/usr/local/s-ui/sui uri"
