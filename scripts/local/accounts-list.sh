#!/bin/bash
# 列出账号编号与打码邮箱（只读，绝不输出密码/TOTP等凭证）
# 输出 JSON：[{"index":"1","email":"a***@qq.com","active":true}, ...]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(cd "$SCRIPT_DIR/../.." && pwd)"

python3 - "$PROJECT/.env" <<'PY'
import re, json, sys
try:
    text = open(sys.argv[1], encoding='utf8').read()
except FileNotFoundError:
    print('[]'); raise SystemExit

# 每行：可选 # + ACCOUNT_N_KEY=value
rows = {}
for line in text.splitlines():
    m = re.match(r'\s*(#?)\s*ACCOUNT_([1-9]\d*)_([A-Z0-9_]+)\s*=\s*(.*)$', line)
    if not m:
        continue
    commented, idx, key, val = m.group(1), m.group(2), m.group(3), m.group(4).strip()
    rows.setdefault(idx, {})[key] = (val, bool(commented))

def mask(email):
    if not email:
        return ''
    if '@' not in email:
        return email[:1] + '***'
    name, domain = email.rsplit('@', 1)
    head = name[0] if name else ''
    tail = name[-1] if len(name) > 1 else ''
    return f'{head}***{tail}@{domain}'

out = []
for idx in sorted(rows, key=lambda x: int(x)):
    email, commented = rows[idx].get('EMAIL', ('', False))
    out.append({
        'index': idx,
        'email': mask(email),
        'active': not commented and bool(email),
    })
print(json.dumps(out, ensure_ascii=False))
PY
