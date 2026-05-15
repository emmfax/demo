#!/bin/sh
VERSION=${1:-1.3.10}

echo "Detecting OS..."
OS=$(awk -F= '/^ID=/{print $2}' /etc/os-release)
ARCH=$(uname -m)

echo "OS: $OS, ARCH: $ARCH"
echo "Installing dependencies..."
apk add --no-cache bash curl tar

echo "Downloading S-UI v$VERSION..."
URL="https://github.com/bulianglin/demo/releases/download/$VERSION/s-ui-linux-amd64.tar.gz"
TMP="/tmp/s-ui-$VERSION.tar.gz"

curl -L -o $TMP $URL
if [ $? -ne 0 ]; then
    echo "Download failed. Check URL or version."
    exit 1
fi

echo "Extracting..."
mkdir -p /usr/local/s-ui
tar xzf $TMP -C /usr/local/s-ui --strip-components=1

echo "Creating start script..."
cat >/usr/local/bin/s-ui <<'EOF'
#!/bin/sh
case "$1" in
    start)
        nohup /usr/local/s-ui/sui >/dev/null 2>&1 &
        echo "S-UI started."
        ;;
    stop)
        pkill -f /usr/local/s-ui/sui
        echo "S-UI stopped."
        ;;
    restart)
        $0 stop
        sleep 1
        $0 start
        ;;
    status)
        pgrep -af sui
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        ;;
esac
EOF

chmod +x /usr/local/bin/s-ui

echo "Installation finished. Use 's-ui start' to run."
