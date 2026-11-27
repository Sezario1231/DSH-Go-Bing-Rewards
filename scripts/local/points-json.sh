#!/bin/bash
# 输出当天积分明细 JSON，供 dsh-go 面板插件读取（只读，纯文本解析日志）
# 用法：bash scripts/local/points-json.sh [YYYY-MM-DD]
PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DAY="${1:-$(TZ=Asia/Shanghai date +%F)}"
LOG="$PROJECT/logs/cron-$DAY.log"
AWK="$PROJECT/scripts/local/points-parse.awk"

if [ ! -f "$LOG" ]; then
    printf '{"date":"%s","exists":false,"accounts":[]}\n' "$DAY"
    exit 0
fi

DATA=$(awk -f "$AWK" "$LOG")
printf '{"date":"%s","exists":true,"accounts":%s}\n' "$DAY" "$DATA"
