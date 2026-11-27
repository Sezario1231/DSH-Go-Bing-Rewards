#!/bin/bash
# 每日积分汇报（供 DSH 15:30 定时任务调用）
# 输出：今天的积分变化、各任务完成情况、是否需要补跑
# 只读，不修改任何运行状态

set -u
export TZ="Asia/Shanghai"
PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT" || { echo "项目目录不存在"; exit 1; }
DAY=$(date +%F)
LOG="$PROJECT/logs/cron-$DAY.log"

echo "══════════ 每日积分汇报 $DAY ══════════"
echo "生成时间: $(date '+%F %T')"
echo

if [ ! -f "$LOG" ]; then
    echo "❌ 今天没有运行日志（$LOG 不存在）"
    echo "建议：立即补跑 → bash scripts/local/daily-run.sh"
    exit 0
fi

echo "【运行状态】"
if grep -q "RUN-END" "$LOG"; then
    grep "RUN-END" "$LOG" | tail -1 | sed 's/^/  /'
else
    echo "  未发现 RUN-END（本轮可能还在跑或中途失败）"
fi
echo "  开始次数: $(grep -c '===== 开始' "$LOG")"
echo "  结束次数: $(grep -c '===== 结束' "$LOG")"

# 是否有进程在跑
running=$(for p in /proc/[0-9]*; do
    [ -r "$p/cmdline" ] || continue
    c=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null) || continue
    case "$c" in *"node ./dist/index.js"*) echo x; break;; esac
done)
[ -n "$running" ] && echo "  ⚠️ 当前仍有实例在运行" || echo "  当前无运行实例"

echo
echo "【积分变化】"
# 按账号提取余额轨迹（日志格式: [时间] [账号] [模块] ... currentBalance=N）
grep -oE 'currentBalance=[0-9]+' "$LOG" | awk -F= '{print $2}' > /tmp/bal.$$ 2>/dev/null
if [ -s /tmp/bal.$$ ]; then
    first=$(head -1 /tmp/bal.$$); last=$(tail -1 /tmp/bal.$$)
    echo "  全局余额: $first → $last (当前累计变化 $((last-first)))"
else
    echo "  未提取到余额数据"
fi
rm -f /tmp/bal.$$

echo
echo "【各账号任务完成情况】"
for acct in $(grep -oE '\] \[[^]]+\] \[' "$LOG" | sed -E 's/^\] \[([^]]+)\] \[.*/\1/' | sort -u); do
    [ "$acct" = "MAIN" ] && continue
    echo "  ── $acct"
    tasks=$(grep "$acct" "$LOG" | grep -oE '\[(DAILY-SET|MORE-PROMOTIONS|READ-TO-EARN|SEARCH-BING|DAILY-CHECK-IN)\]')
    for t in DAILY-SET MORE-PROMOTIONS READ-TO-EARN SEARCH-BING DAILY-CHECK-IN; do
        cnt=$(echo "$tasks" | grep -c "$t")
        [ "$cnt" -gt 0 ] && echo "     $t: $cnt 条记录"
    done
    gained=$(grep "$acct" "$LOG" | grep -oE 'pointsGained=[0-9]+' | awk -F= '{s+=$2} END{print s+0}')
    echo "     累计得分记录合计: $gained"
done

echo
echo "【错误】"
errs=$(grep -c '\[ERROR\]' "$LOG" || true)
benign=$(grep '\[ERROR\]' "$LOG" | grep -c '签到未确认到账' || true)
real=$((errs - benign)); [ "$real" -lt 0 ] && real=0
echo "  ERROR 条数: $errs（其中签到重复等良性 $benign 条，实际需关注 $real 条）"
grep '\[ERROR\]' "$LOG" | grep -v '签到未确认到账' | tail -5 | sed 's/^/    /' | cut -c1-150
[ "$benign" -gt 0 ] && echo "    （另有 $benign 条「签到未确认到账」为已到账后的重复尝试，非失败）"

echo
echo "【风控信号】"
risk=0
for sig in "疑似受限=true" "bot标记=true" "活动折叠=true"; do
    cnt=$(grep -c "$sig" "$LOG" 2>/dev/null || true)
    if [ "${cnt:-0}" -gt 0 ]; then
        echo "  ⚠️ $sig : $cnt 次"
        risk=1
    else
        echo "  ✓ $sig : 0"
    fi
done
warns=$(grep -oE 'userWarnings=[^ |]+' "$LOG" 2>/dev/null | grep -v 'userWarnings=无' | sort -u | tr '\n' ' ' || true)
if [ -n "$warns" ]; then
    echo "  ⚠️ userWarnings: $warns"
    risk=1
else
    echo "  ✓ userWarnings: 无"
fi
score=$(grep -oE 'serpbotscore=[^ |]+' "$LOG" 2>/dev/null | sort -u | tr '\n' ' ' || true)
[ -n "$score" ] && echo "  serpbotscore: $score（未知=主接口不可用，非风险）"

echo
echo "【判断】"
failed=0
if [ ! -f "$LOG" ]; then
    failed=1
elif grep -q '\[ERROR\].*致命错误\|FLOW.*失败\|BOOTSTRAP.*失败' "$LOG"; then
    failed=1
elif ! grep -q 'RUN-END' "$LOG"; then
    failed=1
fi
if [ "$failed" -eq 1 ]; then
    echo "  ⚠️ 本轮存在未完成/失败迹象，建议补跑"
    echo "  补跑命令: bash scripts/local/daily-run.sh"
else
    echo "  ✅ 本轮看起来正常完成"
fi
if [ "$risk" -eq 1 ]; then
    echo "  ℹ️ 检测到风控信号（已在上方列出），仅作记录，不阻断自动补跑"
else
    echo "  ✅ 未发现风控信号"
fi
echo "════════════════════════════════════"
