#!/bin/bash
# Microsoft Rewards 每日调度守护（不依赖 cron）
#
# 背景：本机是 Android 上的 proot/Ubuntu 容器，CapEff=0 且 Seccomp 生效，
# Debian 版 cron 无法正常 fork 执行任务（实测安装成功但不触发）。
# 因此改用常驻 shell 循环：自己计算下次运行时刻，到点就调 daily-run.sh。
#
# 用法：
#   nohup bash scripts/local/scheduler.sh > /dev/null 2>&1 &     # 后台常驻
#   bash scripts/local/stop-scheduler.sh                         # 停止
#   tail -f logs/scheduler.log                                   # 看调度日志
#
# 改运行时间：编辑下面的 RUN_HOUR / RUN_MINUTE 后重启调度器即可。

set -u

PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG="$PROJECT/logs/scheduler.log"
TZ_TARGET="Asia/Shanghai"

# ===== 运行时刻（24 小时制，设备本地时间）=====
RUN_HOUR=9
RUN_MINUTE=0

# 强制按十进制解析，避免 "09" 被当成八进制（bash 会把 09 判为非法八进制）
RUN_HOUR_D=$((10#$RUN_HOUR))
RUN_MINUTE_D=$((10#$RUN_MINUTE))
RUN_CLOCK=$(printf "%02d:%02d" "$RUN_HOUR_D" "$RUN_MINUTE_D")

mkdir -p "$PROJECT/logs"
export TZ="$TZ_TARGET"
cd "$PROJECT" || exit 1

log() {
    echo "[$(date '+%F %T')] $*" >> "$LOG"
}

log "调度器启动 | 目标时刻=每天 ${RUN_CLOCK} | 时区=$TZ_TARGET | pid=$$"

while true; do
    # 计算距离下一个目标时刻还有多少秒
    now_epoch=$(date +%s)
    today_target=$(date -d "today ${RUN_CLOCK}" +%s 2>/dev/null)

    if [ -z "$today_target" ]; then
        log "时间计算失败，60 秒后重试"
        sleep 60
        continue
    fi

    if [ "$today_target" -le "$now_epoch" ]; then
        # 今天的目标时刻已过，顺延到明天
        next_target=$(date -d "tomorrow ${RUN_CLOCK}" +%s)
    else
        next_target=$today_target
    fi

    wait_seconds=$((next_target - now_epoch))
    log "下一次运行: $(date -d "@$next_target" '+%F %T') | 等待 ${wait_seconds} 秒"

    # 分段睡眠：每 60 秒醒一次，避免长时间 sleep 导致时间漂移，
    # 也便于外部 kill 后快速退出
    remaining=$wait_seconds
    while [ "$remaining" -gt 0 ]; do
        step=60
        [ "$remaining" -lt "$step" ] && step=$remaining
        sleep "$step"
        remaining=$((remaining - step))
    done

    log "===== 到达运行时刻，开始执行 ====="
    bash "$PROJECT/scripts/local/daily-run.sh"
    code=$?
    log "===== 本轮结束 | 退出码=$code ====="

    # 防止同一分钟内重复触发
    sleep 60
done
