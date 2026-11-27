#!/bin/bash
# 资源采样器：每 30s 记录内存/进程RSS/温度
out="$1"
echo "ts,used_mi,avail_mi,chrome_rss_mb,node_rss_mb,tz0_c,tz1_c,proc_count" > "$out"
while true; do
  ts=$(date +%H:%M:%S)
  read -r _ tot used free _ bufcache avail < <(free -m | awk '/^Mem:/{print $1,$2,$3,$4,$5,$6,$7}')
  chrome=0; node=0; pc=0
  for d in /proc/[0-9]*; do
    [ -r "$d/statm" ] || continue
    cmd=$(tr '\0' ' ' < "$d/cmdline" 2>/dev/null) || continue
    [ -z "$cmd" ] && continue
    pc=$((pc+1))
    rss=$(awk '{print $2*4/1024}' "$d/statm" 2>/dev/null | cut -d. -f1)
    case "$cmd" in
      *chrome-linux*|*headless_shell*) chrome=$((chrome + ${rss:-0})) ;;
      *dist/index.js*) node=$((node + ${rss:-0})) ;;
    esac
  done
  t0=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
  t1=$(cat /sys/class/thermal/thermal_zone1/temp 2>/dev/null)
  echo "$ts,$used,$avail,$chrome,$node,$t0,$t1,$pc" >> "$out"
  sleep 30
done
