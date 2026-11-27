#!/bin/bash
# 今日任务健康检测（只读）：输出运行状态 JSON，供面板健康卡读取。
# 不启动、不停止任何进程，仅依据日志 + 进程判断。
# 用法：bash scripts/local/health-json.sh
export TZ="Asia/Shanghai"
PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DAY="$(date +%F)"
LOG="$PROJECT/logs/cron-$DAY.log"
NOW_H="$(date +%H)"

# 是否正在运行（node ./dist/index.js 实例）
running=0
for p in /proc/[0-9]*; do
    [ -r "$p/cmdline" ] || continue
    c=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null) || continue
    case "$c" in *"node ./dist/index.js"*) running=1; break;; esac
done

has_run_end=0
has_start=0
has_error=0
last_end=""
start_count=0
if [ -f "$LOG" ]; then
    grep -q 'RUN-END' "$LOG" && has_run_end=1
    grep -q 'ACCOUNT-START' "$LOG" && has_start=1
    grep -q '\[ERROR\].*致命错误\|BOOTSTRAP.*失败' "$LOG" && has_error=1
    start_count=$(grep -c '===== 开始' "$LOG")
    last_end=$(grep 'RUN-END' "$LOG" | tail -1)
fi

# 判定状态
if [ "$has_run_end" -eq 1 ]; then
    status="done"; label="今日已完成"; tone="good"
    detail="本轮已跑完并写出 RUN-END"
elif [ "$running" -eq 1 ]; then
    status="running"; label="运行中"; tone="info"
    detail="积分脚本正在执行，请耐心等待"
elif [ "$has_start" -eq 1 ] || [ "$start_count" -gt 0 ]; then
    status="interrupted"; label="可能中断"; tone="warn"
    detail="今天有启动记录但没有完成标记，可能需要补跑"
else
    # 未启动：过了中午算漏跑，否则算未到时间
    if [ "$NOW_H" -ge 12 ] 2>/dev/null; then
        status="missed"; label="今日可能漏跑"; tone="bad"
        detail="已过中午仍无运行记录，建议启动"
    else
        status="pending"; label="今日尚未启动"; tone="muted"
        detail="还没到例行运行时间或尚未手动启动"
    fi
fi

# 致命错误覆盖
if [ "$status" = "done" ] && [ "$has_error" -eq 1 ]; then
    status="interrupted"; label="完成但有致命错误"; tone="warn"
    detail="有 RUN-END 但日志出现致命错误，建议查看"
fi

# JSON 转义（去掉双引号/反斜杠，日志尾行可能含特殊字符）
esc() { printf '%s' "$1" | tr -d '\\"' | cut -c1-160; }

printf '{"date":"%s","status":"%s","label":"%s","tone":"%s","detail":"%s","running":%d,"runEnd":%d,"startCount":%d,"lastEnd":"%s","hour":%d}\n' \
    "$DAY" "$status" "$label" "$tone" "$(esc "$detail")" \
    "$running" "$has_run_end" "$start_count" "$(esc "$last_end")" "$NOW_H"
