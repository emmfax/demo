#!/bin/sh
VER="1.8"
BASE="/usr/local/s-ui"
SUI="$BASE/sui"
ONE="/usr/local/one.sh"
SHORT="/usr/local/bin/suio"
SCRIPT_URL="https://sui.upb.cc"
REPO_USER="alireza0"
REPO_NAME="s-ui"

[ "$(id -u)" != "0" ]&&echo "请使用root运行"&&exit 1
[ -t 0 ]||exec </dev/tty

cleanup(){
rm -f /tmp/sui.sh /tmp/s-ui.tar.gz
rm -rf /tmp/s-ui-update
rm -f /root/sui.sh ./sui.sh
hash -r 2>/dev/null
}

installed(){
[ -x "$SUI" ]
}

running(){
pidof sui >/dev/null 2>&1
}

dep(){
if command -v apk >/dev/null;then
apk add --no-cache wget curl tar gzip >/dev/null 2>&1
elif command -v apt >/dev/null;then
apt update >/dev/null 2>&1
apt install -y wget curl tar gzip >/dev/null 2>&1
fi
}

arch(){
case "$(uname -m)" in
x86_64|amd64) echo amd64;;
aarch64|arm64) echo arm64;;
*) echo amd64;;
esac
}

service_create(){
if command -v systemctl >/dev/null;then
cat >/etc/systemd/system/s-ui.service <<EOF
[Unit]
Description=s-ui
After=network.target
[Service]
WorkingDirectory=/usr/local/s-ui
ExecStart=/usr/local/s-ui/sui
Restart=always
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
else
cat >/etc/init.d/s-ui <<EOF
#!/sbin/openrc-run
name="s-ui"
command="/usr/local/s-ui/sui"
command_background=true
pidfile="/run/s-ui.pid"
depend(){
after net
}
EOF
chmod +x /etc/init.d/s-ui
fi
}

service_enable(){
if command -v systemctl >/dev/null;then
systemctl enable s-ui >/dev/null 2>&1
elif command -v rc-update >/dev/null;then
rc-update add s-ui default >/dev/null 2>&1
fi
}

service_start(){
if command -v systemctl >/dev/null;then
systemctl start s-ui
elif command -v rc-service >/dev/null;then
rc-service s-ui start
fi
}

service_stop(){
if command -v systemctl >/dev/null;then
systemctl stop s-ui
elif command -v rc-service >/dev/null;then
rc-service s-ui stop
fi
}

service_restart(){
service_stop
sleep 1
service_start
}

create_suio(){
cat >"$SHORT" <<EOF
#!/bin/sh
/usr/local/one.sh
EOF
chmod +x "$SHORT"
}

cleanup
