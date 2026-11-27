#!/bin/bash
# cron 看门狗：proot 容器无 systemd，App 被回收后 cron 会静默消失。
# 本脚本检查 cron 是否在跑，不在则拉起，并记录到 logs/cron-watchdog.log
#
# 用法：由 crontab 每 30 分钟调用一次（cron 不在时它自己也被杀掉，
#       所以真正的兜底是开机/App 启动后手动跑一次本脚本）
PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG="$PROJECT/logs/cron-watchdog.log"
mkdir -p "$(dirname "$LOG")"

running=0
for p in /proc/[0-9]*; do
    c=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null) || continue
    case "$c" in
        *"/sbin/cron"*) running=1; break ;;
    esac
done

if [ "$running" -eq 0 ]; then
    service cron start >> "$LOG" 2>&1
    echo "[$(date '+%F %T')] cron 不在运行，已拉起" >> "$LOG"
else
    : # 正常时不必刷日志
fi
