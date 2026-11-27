#!/bin/bash
# 只运行账号2：在环境里屏蔽账号1邮箱（不碰 .env），让脚本仅加载第二个账号
# 复用 daily-run.sh 的 flock / 日志 / 残留清理逻辑
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

# 屏蔽账号1：设为空字符串（非 undefined），ensureEnvLoaded 就不会从 .env 读取它，
# getAccountIndexes() 因邮箱为空而跳过，只保留账号2。
export ACCOUNT_1_EMAIL=""

exec 9>"$LOCK"
if ! flock -n 9; then
    echo "[$(date '+%F %T')] 上一轮仍在运行，跳过本次（账号2）" >> "$LOG"
    exit 0
fi

echo "===== 开始账号2单跑 $(date '+%F %T') =====" >> "$LOG"

cleanup_stale() {
    local killed=0
    local self=$$
    local parent=$PPID
    for p in /proc/[0-9]*; do
        pid="${p#/proc/}"
        [ "$pid" = "$self" ] && continue
        [ "$pid" = "$parent" ] && continue
        [ -r "$p/cmdline" ] || continue
        cmdline=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null) || continue
        [ -z "$cmdline" ] && continue
        case "$cmdline" in
            *bash*|*"sh -c"*|*daily-run*|*run-account2*) continue ;;
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
echo "===== 结束账号2单跑 $(date '+%F %T') | 退出码=$CODE =====" >> "$LOG"
exit $CODE
