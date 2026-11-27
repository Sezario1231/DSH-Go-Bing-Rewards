#!/bin/bash
# 一键自检 + 自愈：每次打开 DSH App 后运行一次
#
# 它会做几件事：
#   1. 检查旧容器调度器是否残留（当前采用 DSH 定时任务，调度器应停用）
#   2. 检查上次运行情况，告诉你今天跑过没有
#   3. 检查会话/配置是否正常
#
# 注意：本脚本绝不自动拉起 scheduler.sh。运行由 DSH 定时任务（09:00）负责。
#
# 用法：bash /root/workspace/microsoft-rewards-script/scripts/local/doctor.sh

set -u

PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="$PROJECT/logs"
SCHED_LOG="$LOG_DIR/scheduler.log"
DAY="$(date +%F)"

export TZ="Asia/Shanghai"
cd "$PROJECT" || { echo "❌ 项目目录不存在: $PROJECT"; exit 1; }

GREEN='\033[32m'; RED='\033[31m'; YELLOW='\033[33m'; DIM='\033[2m'; NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $*"; }
bad()  { echo -e "${RED}✗${NC} $*"; }
warn() { echo -e "${YELLOW}!${NC} $*"; }
note() { echo -e "${DIM}$*${NC}"; }

echo "════════════════════════════════════════"
echo " Microsoft Rewards 自检  $(date '+%F %T')"
echo "════════════════════════════════════════"

# ---------- 1. 调度方式 ----------
echo
echo "【1】调度方式（当前采用 DSH 定时任务，容器调度器应停用）"
sched_pid=""
for p in /proc/[0-9]*; do
    [ -r "$p/cmdline" ] || continue
    case "$p" in "/proc/$$"|"/proc/$PPID") continue ;; esac
    c=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null) || continue
    case "$c" in
        *scheduler.sh*|*cron*) sched_pid="${p#/proc/}"; break ;;
    esac
done

ok "每日唤醒由 DSH 定时任务负责（09:00 启动 / 15:30 检查）"
if [ -n "$sched_pid" ]; then
    warn "发现旧容器调度器残留 (pid=$sched_pid) —— 它会和 DSH 定时冲突，建议停止："
    note "   bash scripts/local/stop-scheduler.sh"
else
    ok "无旧调度器/cron 残留（符合当前调度模型）"
fi

# ---------- 2. 今日运行情况 ----------
echo
echo "【2】今日运行 ($DAY)"
today_log="$LOG_DIR/cron-$DAY.log"
if [ -f "$today_log" ]; then
    if grep -q "RUN-END" "$today_log" 2>/dev/null; then
        ok "今天已跑完一轮"
        grep -E "RUN-END" "$today_log" | tail -1 | sed 's/^/   /'
    elif grep -q "RUN-START" "$today_log" 2>/dev/null; then
        running=$(for p in /proc/[0-9]*; do
            [ -r "$p/cmdline" ] || continue
            case "$p" in "/proc/$$"|"/proc/$PPID") continue ;; esac
            c=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null) || continue
            case "$c" in *"node ./dist/index.js"*) echo x; break ;; esac
        done)
        if [ -n "$running" ]; then
            warn "正在运行中"
            tail -1 "$today_log" | sed 's/^/   /'
        else
            warn "今天启动过但未正常结束（可能被中断）"
            tail -3 "$today_log" | sed 's/^/   /'
        fi
    else
        warn "日志存在但无运行记录"
    fi
else
    warn "今天还没有运行记录"
    note "   下次自动运行时间见上方调度器信息"
fi

# ---------- 3. 会话 ----------
echo
echo "【3】登录会话"
node -e '
const {DatabaseSync}=require("node:sqlite");
try{
  const db=new DatabaseSync("sessions/sessions.db");
  const rows=db.prepare("SELECT email,platform,updated_at FROM sessions").all();
  if(!rows.length){console.log("   ✗ 无任何会话，需要重新登录");process.exit(0)}
  const byEmail={};
  for(const r of rows){ (byEmail[r.email] ||= []).push(r) }
  for(const [email,list] of Object.entries(byEmail)){
    const mask=email.replace(/^(.{2}).*(@.*)$/,"$1***$2");
    const newest=Math.max(...list.map(r=>r.updated_at));
    const hours=((Date.now()-newest)/3600000).toFixed(1);
    const platforms=list.map(r=>r.platform).join("+");
    console.log(`   ✓ ${mask}  ${platforms}  ${hours}h 前`);
  }
}catch(e){ console.log("   ✗ 读取会话库失败: "+e.message) }
' 2>/dev/null || echo "   ✗ 无法读取会话库"

# ---------- 4. 配置 ----------
echo
echo "【4】配置"
node -e '
const {loadAccounts,loadConfig}=require("./dist/util/Load.js");
try{
  const a=loadAccounts(), c=loadConfig();
  console.log(`   ✓ 账号数: ${a.length}`);
  console.log(`   ✓ headless=${c.headless} clusters=${c.clusters} 账号间隔=${c.accountDelay.min}~${c.accountDelay.max}`);
  console.log(`   ✓ 搜索间隔=${c.searchSettings.searchDelay.min}~${c.searchSettings.searchDelay.max}`);
}catch(e){ console.log("   ✗ 配置有问题: "+e.message) }
' 2>/dev/null || echo "   ✗ 配置检查失败"

# ---------- 5. 残留进程 ----------
echo
echo "【5】残留进程"
running_pids=$(for p in /proc/[0-9]*; do
    [ -r "$p/cmdline" ] || continue
    case "$p" in "/proc/$$"|"/proc/$PPID") continue ;; esac
    c=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null) || continue
    # 排除 shell 包装与查询命令，只匹配真正的运行实例
    case "$c" in *bash*|*"sh -c"*|*"/proc/"*) continue ;; esac
    case "$c" in *"node ./dist/index.js"*) echo "${p#/proc/}" ;; esac
done | tr '\n' ' ')
if [ -z "$running_pids" ]; then
    ok "无残留运行实例"
else
    warn "有运行中的实例: $running_pids"
    note "   清理: bash scripts/local/stop-scheduler.sh"
fi

echo
echo "════════════════════════════════════════"
echo " 常用命令"
echo "   手动跑一轮  bash scripts/local/daily-run.sh"
echo "   看运行日志  tail -f logs/cron-\$(date +%F).log"
echo "   积分汇报    bash scripts/local/daily-report.sh"
echo "   全部停止    bash scripts/local/stop-scheduler.sh"
echo " 定时唤醒由 DSH App 负责（09:00 / 15:30），容器内无需常驻调度器"
echo "════════════════════════════════════════"
