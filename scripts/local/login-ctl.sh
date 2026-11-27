#!/bin/bash
# 交互式登录的命令行控制器：向 /tmp/msr/cmd.json 下发操作，等待并读回 out.json
# 供 AI 在添加账号流程中控制浏览器；凭证（邮箱/验证码/密码）由用户在对话提供，
# 本脚本只把它写进临时命令文件，不写入对话日志或持久文件。
# 用法：
#   bash scripts/local/login-ctl.sh shot <name>          # 截图到 logs/shots/<name>.png
#   bash scripts/local/login-ctl.sh goto <url>           # 导航
#   bash scripts/local/login-ctl.sh clicktext <text>     # 按可见文字点击
#   bash scripts/local/login-ctl.sh click <sel>          # 按 CSS 选择器点击
#   bash scripts/local/login-ctl.sh fill <sel> <value>   # 填写输入框
#   bash scripts/local/login-ctl.sh type <value>         # 向当前焦点输入
#   bash scripts/local/login-ctl.sh key <key>            # 按键，如 Enter
#   bash scripts/local/login-ctl.sh eval <js>            # 执行 JS 表达式
#   bash scripts/local/login-ctl.sh save <email> [mobile|desktop]
#   bash scripts/local/login-ctl.sh quit
set -euo pipefail
DIR=/tmp/msr
CMD="$DIR/cmd.json"
OUT="$DIR/out.json"
mkdir -p "$DIR"

op="${1:-}"
[ -z "$op" ] && { echo "用法见脚本头部注释" >&2; exit 1; }
shift

case "$op" in
  shot)    json=$(python3 -c 'import json,sys; print(json.dumps({"op":"shot","name":sys.argv[1]}))' "${1:-shot}") ;;
  goto)    json=$(python3 -c 'import json,sys; print(json.dumps({"op":"goto","url":sys.argv[1]}))' "$1") ;;
  clicktext) json=$(python3 -c 'import json,sys; print(json.dumps({"op":"clicktext","text":sys.argv[1]}))' "$1") ;;
  click)   json=$(python3 -c 'import json,sys; print(json.dumps({"op":"click","sel":sys.argv[1]}))' "$1") ;;
  fill)    json=$(python3 -c 'import json,sys; print(json.dumps({"op":"fill","sel":sys.argv[1],"value":sys.argv[2]}))' "$1" "$2") ;;
  type)    json=$(python3 -c 'import json,sys; print(json.dumps({"op":"type","value":sys.argv[1]}))' "$1") ;;
  key)     json=$(python3 -c 'import json,sys; print(json.dumps({"op":"key","key":sys.argv[1]}))' "$1") ;;
  eval)    json=$(python3 -c 'import json,sys; print(json.dumps({"op":"eval","js":sys.argv[1]}))' "$1") ;;
  save)    json=$(python3 -c 'import json,sys; print(json.dumps({"op":"save","email":sys.argv[1],"platform":sys.argv[2] if len(sys.argv)>2 else "mobile"}))' "$1" "${2:-mobile}") ;;
  quit)    json='{"op":"quit"}' ;;
  *) echo "未知操作：$op" >&2; exit 1 ;;
esac

rm -f "$OUT"
printf '%s' "$json" > "$CMD"

# 等待浏览器处理（最多 90 秒）
for i in $(seq 1 180); do
  [ -f "$OUT" ] && break
  sleep 0.5
done
if [ ! -f "$OUT" ]; then echo "超时：浏览器未响应" >&2; exit 1; fi
cat "$OUT"
echo
