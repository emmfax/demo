#!/bin/sh
# alpine-s-ui-postinstall.sh
# Alpine Linux 上 S-UI 启动与依赖补全

INSTALL_DIR="/usr/local/s-ui"

echo "Step 1: 安装必要依赖..."
apk update
apk add bash socat curl tar coreutils openrc

echo "Step 2: 确保安装目录存在..."
mkdir -p "$INSTALL_DIR"

echo "Step 3: 创建 OpenRC 服务..."
cat <<EOF > /etc/init.d/s-ui
#!/sbin/openrc-run
# Alpine OpenRC service for S-UI
name="s-ui"
description="S-UI Panel Service"
command="$INSTALL_DIR/sui"
command_args=""   # 不传 start 参数
pidfile="/run/s-ui.pid"

depend() {
    need net
}

start_pre() {
    checkpath --directory --mode 0755 /run
}

start() {
    ebegin "Starting S-UI"
    start-stop-daemon --start --background --make-pidfile --pidfile \$pidfile --exec \$command -- \$command_args
    eend \$?
}

stop() {
    ebegin "Stopping S-UI"
    start-stop-daemon --stop --pidfile \$pidfile --retry 5
    eend \$?
}
EOF

chmod +x /etc/init.d/s-ui
rc-update add s-ui default

echo "Step 4: 启动 S-UI..."
rc-service s-ui start

echo "Step 5: 检查 S-UI 是否运行..."
if pgrep -f sui >/dev/null; then
    echo "S-UI is running!"
else
    echo "S-UI failed to start. Check logs in $INSTALL_DIR."
fi

echo "Post-install script finished. OpenRC service has been set up for S-UI."
