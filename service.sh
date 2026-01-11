#!/system/bin/sh
# Device: Xiaomi 13
# HyperOS 3.0.2.0 | Android 15 | KernelSU 3.0.0
# Secure + Self-Healing + Configurable ADB over TCP

CONF_DIR="/data/adb/modules/ksu-adbd-tcp"
PORT_CONF="$CONF_DIR/adb_port.conf"
CHECK_INTERVAL=60

# 默认端口
ADB_PORT=5555

# 等系统完全启动
sleep 40

# 读取端口配置
if [ -f "$PORT_CONF" ]; then
    CONF_PORT=$(cat "$PORT_CONF" | tr -d '\r\n')
    case "$CONF_PORT" in
        ''|*[!0-9]*)
            ;;
        *)
            ADB_PORT="$CONF_PORT"
            ;;
    esac
fi

start_adbd() {
    setprop persist.sys.usb.config adb
    setprop persist.service.adb.enable 1
    setprop service.adb.tcp.port "$ADB_PORT"
    stop adbd
    start adbd
}

apply_firewall() {
    # 清理旧规则
    iptables -D INPUT -p tcp --dport "$ADB_PORT" -j ACCEPT 2>/dev/null
    iptables -D INPUT -p tcp --dport "$ADB_PORT" -j DROP 2>/dev/null

    # 允许内网 IP
    iptables -A INPUT -p tcp --dport "$ADB_PORT" -s 192.168.0.0/16 -j ACCEPT
    iptables -A INPUT -p tcp --dport "$ADB_PORT" -s 10.0.0.0/8 -j ACCEPT
    iptables -A INPUT -p tcp --dport "$ADB_PORT" -s 172.16.0.0/12 -j ACCEPT

    # 拒绝其他来源
    iptables -A INPUT -p tcp --dport "$ADB_PORT" -j DROP
}

# 初始启动
start_adbd
apply_firewall

# 自愈守护
while true; do
    sleep "$CHECK_INTERVAL"

    CUR_PORT=$(getprop service.adb.tcp.port)

    if ! pidof adbd >/dev/null 2>&1 || [ "$CUR_PORT" != "$ADB_PORT" ]; then
        start_adbd
        apply_firewall
    fi
done
