#!/bin/bash
# 一键启动今日任务（不调用 AI，供手机终端手动触发）
# 用法：bash scripts/local/start.sh
PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG="$PROJECT/logs/cron-$(date +%F).log"

cd "$PROJECT" || exit 1

# 已经在跑就不再叠加
if pgrep -f "node ./dist/index.js" >/dev/null 2>&1; then
    echo "⚠️ 已在运行中，未重复启动。"
    echo "   实时日志：tail -f $LOG"
    exit 0
fi

nohup bash scripts/local/daily-run.sh >/dev/null 2>&1 &
echo "✅ 已启动（PID $!）"
echo "   等约 60 秒后查看：tail -f $LOG"
