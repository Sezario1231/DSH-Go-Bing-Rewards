#!/bin/bash
# 输出近几天/月积分汇总 + 风控信号 JSON，供面板读取（只读日志）
PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AWK="$PROJECT/scripts/local/points-summary.awk"
LOGS=$(ls -1 "$PROJECT"/logs/cron-*.log 2>/dev/null | sort)

if [ -z "$LOGS" ]; then
    printf '{"days":[],"months":[]}\n'
    exit 0
fi

awk -f "$AWK" $LOGS
