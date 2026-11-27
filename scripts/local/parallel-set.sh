#!/bin/bash
# 设置账号运行的串行/并行度（只改 config.json 的 clusters，不碰凭证）
# 用法：
#   bash scripts/local/parallel-set.sh          # 显示当前设置
#   bash scripts/local/parallel-set.sh 1        # 串行（默认）
#   bash scripts/local/parallel-set.sh 2        # 并行，最多 2 个账号同时跑
# 建议并行不超过 3，总账号不超过 6。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG="$PROJECT/config.json"

cd "$PROJECT"

current() {
  python3 -c 'import json; print(json.load(open("config.json")).get("clusters", 1))'
}

if [ "$#" -eq 0 ]; then
  n="$(current)"
  if [ "$n" -le 1 ]; then mode="串行"; else mode="并行（最多 $n 个账号同时）"; fi
  echo "当前 clusters=$n → $mode"
  echo "用法：bash scripts/local/parallel-set.sh <1-3>"
  exit 0
fi

n="$1"
case "$n" in
  ''|*[!0-9]*) echo "错误：参数必须是数字 1-3" >&2; exit 1 ;;
esac
if [ "$n" -lt 1 ] || [ "$n" -gt 3 ]; then
  echo "错误：并行度 1-3（1=串行）；建议不超过 3" >&2
  exit 1
fi

# 账号总数上限 6：按 ACCOUNT_N_EMAIL 计数
account_count="$(python3 - "$PROJECT/.env" <<'PY'
import re, sys
try:
    text = open(sys.argv[1], encoding='utf8').read()
except FileNotFoundError:
    print(0); raise SystemExit
ids = set()
for line in text.splitlines():
    m = re.match(r'\s*#?\s*(ACCOUNT_([1-9]\d*)_EMAIL)\s*=', line)
    if m and not line.lstrip().startswith('#'):
        ids.add(m.group(2))
print(len(ids))
PY
)"
if [ "$account_count" -gt 6 ]; then
  echo "警告：当前账号数 $account_count 超过建议上限 6，请先在面板删除多余账号" >&2
  exit 1
fi

cp "$CONFIG" "$CONFIG.bak.$(date +%Y%m%d%H%M%S)"
python3 - "$CONFIG" "$n" <<'PY'
import json, sys
path, n = sys.argv[1], int(sys.argv[2])
d = json.load(open(path, encoding='utf8'))
d['clusters'] = n
with open(path, 'w', encoding='utf8') as f:
    json.dump(d, f, ensure_ascii=False, indent=2)
    f.write('\n')
PY

if [ "$n" -le 1 ]; then
  echo "已切换为串行（clusters=1）：账号逐个运行，间隔由 accountDelay 控制"
else
  echo "已切换为并行（clusters=$n）：最多 $n 个账号同时运行"
fi
echo "配置已备份为 config.json.bak.*"
echo "提示：正在运行中的任务不受影响，下次启动生效"
