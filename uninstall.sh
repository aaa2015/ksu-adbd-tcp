#!/system/bin/sh

# 关闭 TCP adb
setprop service.adb.tcp.port -1
stop adbd
start adbd

# 清理防火墙规则
for p in $(iptables -S INPUT | grep adbd | awk '{print $2}'); do
    iptables -D INPUT "$p" 2>/dev/null
done
