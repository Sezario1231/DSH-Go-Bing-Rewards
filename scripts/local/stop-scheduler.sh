#!/bin/bash
# 停止每日调度守护（scheduler.sh）及其派生的运行实例
set -u

PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG="$PROJECT/logs/scheduler.log"

killed=0
self=$$
parent=$PPID

for p in /proc/[0-9]*; do
    [ -r "$p/cmdline" ] || continue
    pid="${p#/proc/}"
    [ "$pid" = "$self" ] && continue
    [ "$pid" = "$parent" ] && continue

    cmdline=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null) || continue
    [ -z "$cmdline" ] && continue

    # 排除 stop-scheduler 自身及其调用者（避免自杀）
    case "$cmdline" in
        *stop-scheduler*) continue ;;
    esac

    # 目标：调度器、包装脚本、脚本主体、浏览器
    case "$cmdline" in
        *scheduler.sh*|*daily-run.sh*|*"node ./dist/index.js"*|*chrome-linux/chrome*|*headless_shell*)
            kill -9 "$pid" 2>/dev/null && killed=$((killed + 1))
            ;;
    esac
done

echo "已停止 $killed 个进程"
exit 0
