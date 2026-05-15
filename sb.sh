#!/bin/sh
# alpine-s-ui-postinstall.sh
# 用于 Alpine Linux 的 S-UI 启动和依赖补全

INSTALL_DIR="/usr/local/s-ui"  # 假设 S-UI 已安装到这个目录

echo "Step 1: 安装必要依赖..."
apk update
apk add bash socat curl tar coreutils openrc

echo "Step 2: 创建 OpenRC 服务..."
cat <<EOF > /etc/init.d/s-ui
#!/sbin/openrc-run
command="$INSTALL_DIR/sui"
command_args="start"
pidfile="/run/s-ui.pid"
name="s-ui"
description="S-UI Panel Service"
EOF

chmod +x /etc/init.d/s-ui
rc-update add s-ui default

echo "Step 3: 启动 S-UI..."
rc-service s-ui start

echo "Step 4: 检查 S-UI 状态..."
ps aux | grep sui
echo "如果你看到 sui 进程运行，S-UI 已经正常启动！"

echo "Post-install script finished. OpenRC 已设置开机自启。"
