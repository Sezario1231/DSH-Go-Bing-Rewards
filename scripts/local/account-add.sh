#!/bin/bash
# 添加一个账号：在 .env 追加空白 ACCOUNT_N_* 模板，并启动交互式登录浏览器
# 用法：
#   bash scripts/local/account-add.sh prepare        # 生成下一个编号的空白模板，输出编号
#   bash scripts/local/account-add.sh login          # 启动交互式登录浏览器（供 AI 通过 /tmp/msr/cmd.json 控制）
#   bash scripts/local/account-add.sh finalize <N>   # 登录完成后把该账号标记为启用
# 说明：本脚本绝不读取或输出任何凭证内容；邮箱/验证码由用户在对话中提供，由 AI 填入。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV="$PROJECT/.env"

next_index() {
  python3 - "$ENV" <<'PY'
import re, sys
text = open(sys.argv[1], encoding='utf8').read() if __import__('os').path.exists(sys.argv[1]) else ''
ids = set()
for line in text.splitlines():
    m = re.match(r'\s*#?\s*ACCOUNT_([1-9]\d*)_EMAIL\s*=', line)
    if m: ids.add(int(m.group(1)))
n = 1
while n in ids:
    n += 1
print(n)
PY
}

case "${1:-}" in
  prepare)
    n="$(next_index)"
    total="$(next_index)"  # 下一个编号即当前已占用数+1
    if [ "$total" -gt 6 ]; then
      echo "错误：账号数已达建议上限 6，请先删除不用的账号" >&2
      exit 1
    fi
    cat >> "$ENV" <<EOF

# ---- 账号 $n（添加流程生成，凭证由用户填写）----
ACCOUNT_${n}_EMAIL=
ACCOUNT_${n}_PASSWORD=
ACCOUNT_${n}_TOTP_SECRET=
ACCOUNT_${n}_RECOVERY_EMAIL=
ACCOUNT_${n}_GEO_LOCALE=auto
ACCOUNT_${n}_LANG_CODE=zh-CN
ACCOUNT_${n}_SAVE_FINGERPRINT_MOBILE=true
ACCOUNT_${n}_SAVE_FINGERPRINT_DESKTOP=true
EOF
    chmod 600 "$ENV"
    echo "ACCOUNT_${n}_* 空白模板已追加到 .env（编号 $n）"
    echo "下一步：运行 bash scripts/local/account-add.sh login 启动登录浏览器"
    ;;
  login)
    echo "启动交互式登录浏览器（后台）..."
    cd "$PROJECT"
    nohup node scripts/local/interactive-login.cjs >/tmp/msr/login-browser.log 2>&1 &
    echo "浏览器 PID $!"
    echo "等待 /tmp/msr/ready 出现后即可通过 cmd.json 操作"
    ;;
  finalize)
    n="${2:-}"
    case "$n" in ''|*[!0-9]*) echo "用法：account-add.sh finalize <编号>" >&2; exit 1;; esac
    echo "账号 $n 登录会话已保存。请确认 .env 中 ACCOUNT_${n}_EMAIL 已填写。"
    echo "如邮箱为空，该账号不会被加载；填好后下次启动生效。"
    ;;
  *)
    echo "用法：bash scripts/local/account-add.sh {prepare|login|finalize <N>}" >&2
    exit 1
    ;;
esac
