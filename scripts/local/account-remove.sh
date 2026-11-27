#!/bin/bash
# 删除（注释）一个账号：把 ACCOUNT_N_* 整组行加 # 前缀，凭证不被读取或输出
# 用法：bash scripts/local/account-remove.sh <账号编号>
# 例如：bash scripts/local/account-remove.sh 2
# 注意：只改 .env，不删除 sessions/ 里的登录态；如需彻底清除请手动删除对应会话。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV="$PROJECT/.env"

if [ "$#" -ne 1 ]; then
  echo "用法：bash scripts/local/account-remove.sh <账号编号>" >&2
  exit 1
fi
N="$1"
case "$N" in
  ''|*[!0-9]*) echo "错误：账号编号必须是数字" >&2; exit 1 ;;
esac

if [ ! -f "$ENV" ]; then echo "错误：.env 不存在" >&2; exit 1; fi

# 只统计该编号是否还有未注释的 EMAIL 行
active="$(python3 - "$ENV" "$N" <<'PY'
import re, sys
text = open(sys.argv[1], encoding='utf8').read()
n = sys.argv[2]
for line in text.splitlines():
    if re.match(r'\s*ACCOUNT_%s_EMAIL\s*=' % re.escape(n), line):
        print(1); raise SystemExit
print(0)
PY
)"
if [ "$active" != "1" ]; then
  echo "账号 $N 不存在或已被注释，无需操作" >&2
  exit 1
fi

# 至少保留一个账号
count="$(python3 - "$ENV" <<'PY'
import re, sys
text = open(sys.argv[1], encoding='utf8').read()
ids = set()
for line in text.splitlines():
    m = re.match(r'\s*ACCOUNT_([1-9]\d*)_EMAIL\s*=', line)
    if m: ids.add(m.group(1))
print(len(ids))
PY
)"
if [ "$count" -le 1 ]; then
  echo "错误：这是最后一个账号，不能删除（项目要求至少 1 个账号）" >&2
  exit 1
fi

cp "$ENV" "$ENV.bak.$(date +%Y%m%d%H%M%S)"
chmod 600 "$ENV.bak."* 2>/dev/null || true

python3 - "$ENV" "$N" <<'PY'
import re, sys
path, n = sys.argv[1], sys.argv[2]
lines = open(path, encoding='utf8').read().splitlines(keepends=True)
pat = re.compile(r'^(\s*)ACCOUNT_%s_[A-Z0-9_]+\s*=' % re.escape(n))
out, changed = [], 0
for line in lines:
    if pat.match(line):
        indent = re.match(r'^(\s*)', line).group(1)
        out.append(indent + '#' + line[len(indent):])
        changed += 1
    else:
        out.append(line)
open(path, 'w', encoding='utf8').writelines(out)
print(f'已注释账号 {n} 的 {changed} 行配置')
PY
chmod 600 "$ENV"
echo "凭证未读取、未输出；原 .env 已备份为 .env.bak.*"
echo "该账号的登录态仍在 sessions/ 中，如要彻底清除请手动删除对应会话文件"
echo "下次启动生效"
