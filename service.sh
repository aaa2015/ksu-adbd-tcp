#!/system/bin/sh
# Secure + Self-Healing + Configurable ADB over TCP

MODULE_DIR="/data/adb/modules/ksu-adbd-tcp"
LOG_FILE="$MODULE_DIR/run.log"
PORT_CONF="$MODULE_DIR/adb_port.conf"
CHECK_INTERVAL=60

# 默认端口
ADB_PORT=5555

# 等系统完全启动
sleep 40

echo "$(date) - Starting service.sh" > "$LOG_FILE"

# 读取端口配置文件（如果存在）
if [ -f "$PORT_CONF" ]; then
    CONF_PORT=$(grep -v '^#' "$PORT_CONF" | tr -d '\r\n' | head -n 1)
    case "$CONF_PORT" in
        ''|*[!0-9]*)
            echo "$(date) - No valid port configuration found, using default $ADB_PORT" >> "$LOG_FILE"
            ;;
        *)
            ADB_PORT="$CONF_PORT"
            echo "$(date) - Using custom port: $ADB_PORT" >> "$LOG_FILE"
            ;;
    esac
else
    echo "$(date) - No adb_port.conf found, using default port: $ADB_PORT" >> "$LOG_FILE"
fi

# 启动 adbd 服务
start_adbd() {
    echo "$(date) - Starting adbd with port $ADB_PORT..." >> "$LOG_FILE"
    setprop persist.sys.usb.config adb
    setprop persist.service.adb.enable 1
    setprop service.adb.tcp.port "$ADB_PORT"
    stop adbd
    start adbd
    echo "$(date) - adbd started successfully" >> "$LOG_FILE"
}

# 防火墙配置（仅允许内网 IP）
apply_firewall() {
    echo "$(date) - Applying firewall rules..." >> "$LOG_FILE"

    iptables -D INPUT -p tcp --dport "$ADB_PORT" -j ACCEPT 2>/dev/null
    iptables -D INPUT -p tcp --dport "$ADB_PORT" -j DROP 2>/dev/null

    # 允许内网 IP 访问
    iptables -A INPUT -p tcp --dport "$ADB_PORT" -s 192.168.0.0/16 -j ACCEPT
    iptables -A INPUT -p tcp --dport "$ADB_PORT" -s 10.0.0.0/8 -j ACCEPT
    iptables -A INPUT -p tcp --dport "$ADB_PORT" -s 172.16.0.0/12 -j ACCEPT

    # 拒绝其他来源
    iptables -A INPUT -p tcp --dport "$ADB_PORT" -j DROP

    echo "$(date) - Firewall rules applied successfully" >> "$LOG_FILE"
}

# 启动 adbd 和防火墙
start_adbd
apply_firewall

# 自愈守护循环
echo "$(date) - Starting self-healing loop..." >> "$LOG_FILE"
while true; do
    sleep "$CHECK_INTERVAL"

    # 检查 adbd 进程是否存在
    if ! pidof adbd >/dev/null 2>&1; then
        echo "$(date) - adbd not running, restarting..." >> "$LOG_FILE"
        start_adbd
        apply_firewall
    else
        echo "$(date) - adbd is running" >> "$LOG_FILE"
    fi

    # 检查端口配置
    CUR_PORT=$(getprop service.adb.tcp.port)
    if [ "$CUR_PORT" != "$ADB_PORT" ]; then
        echo "$(date) - Port mismatch detected, restarting adbd..." >> "$LOG_FILE"
        start_adbd
        apply_firewall
    fi
done
