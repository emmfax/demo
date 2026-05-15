#!/bin/sh
# Alpine Linux 一键 S-UI post-install & 启动脚本
# 适用于手动已安装 S-UI 的情况

INSTALL_DIR="/usr/local/s-ui"
LOG_FILE="/var/log/s-ui.log"

echo "Step 1: 安装必要依赖..."
apk update
apk add bash socat curl tar coreutils openrc

echo "Step 2: 确保安装目录存在..."
mkdir -p "$INSTALL_DIR"

echo "Step 3: 创建 OpenRC 服务..."
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
    # nohup 后台启动，日志写入 /var/log/s-ui.log
    nohup "$command" > /var/log/s-ui.log 2>&1 &
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

# 添加开机启动
rc-update add s-ui default

echo "Step 4: 启动 S-UI..."
rc-service s-ui restart

echo "Step 5: 检查 S-UI 是否运行..."
if pgrep -f sui >/dev/null; then
    echo "S-UI 已经在运行！"
    echo "日志文件：$LOG_FILE"
else
    echo "S-UI 启动失败！请检查日志：$LOG_FILE"
fi

echo "脚本执行完成。OpenRC 已设置 S-UI 开机自启。"
echo "使用命令查看面板 URL：/usr/local/s-ui/sui uri"
