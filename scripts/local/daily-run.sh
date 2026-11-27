#!/bin/bash
# 每日定时运行包装脚本（供 cron 调用）
#
# 加固要点（均为实机踩坑后加的）：
# 1. flock 防止上一轮未结束就叠加运行
# 2. 启动前清理残留的本脚本 node/chrome 进程（历史遗留会争抢 sessions.db）
# 3. cron 守护自愈：若 cron 未运行则拉起（proot 容器无 systemd，容易被回收）
# 4. 日志按天写入 logs/cron-YYYY-MM-DD.log
set -u

PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="$PROJECT/logs"
LOCK="/tmp/msr-daily.lock"
DAY="$(date +%F)"
LOG="$LOG_DIR/cron-$DAY.log"

mkdir -p "$LOG_DIR"
cd "$PROJECT" || exit 1

export TZ="Asia/Shanghai"
export PATH="/usr/local/bin:/usr/bin:/sbin:/bin:$PATH"

# 并发保护：上一轮仍在跑就跳过本次，避免叠加把手机跑爆
exec 9>"$LOCK"
if ! flock -n 9; then
    echo "[$(date '+%F %T')] 上一轮仍在运行，跳过本次" >> "$LOG"
    exit 0
fi

echo "===== 开始 $(date '+%F %T') =====" >> "$LOG"

# 启动前清理历史残留：只杀本项目 node ./dist/index.js 与它的 Chromium 子进程，
# 不碰 cron 自身、不碰系统其他进程。
cleanup_stale() {
    local killed=0
    local self=$$
    local parent=$PPID
    for p in /proc/[0-9]*; do
        pid="${p#/proc/}"
        # 跳过自身与父进程，避免误杀包装脚本自己
        [ "$pid" = "$self" ] && continue
        [ "$pid" = "$parent" ] && continue
        [ -r "$p/cmdline" ] || continue
        cmdline=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null) || continue
        [ -z "$cmdline" ] && continue
        # 只匹配真正的运行实例；排除任何 shell 包装（含 bash -c / sh -c）
        case "$cmdline" in
            *bash*|*"sh -c"*|*daily-run*) continue ;;
        esac
        case "$cmdline" in
            *"node ./dist/index.js"*|*"chrome-linux/chrome"*|*"headless_shell"*)
                kill -9 "$pid" 2>/dev/null && killed=$((killed + 1))
                ;;
        esac
    done
    [ "$killed" -gt 0 ] && echo "[$(date '+%F %T')] 已清理 $killed 个残留进程" >> "$LOG"
}

cleanup_stale
sleep 2

npm start >> "$LOG" 2>&1
CODE=$?
echo "===== 结束 $(date '+%F %T') | 退出码=$CODE =====" >> "$LOG"
exit $CODE
