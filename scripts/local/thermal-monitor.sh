#!/bin/bash
# 发热/功耗专用采样器：每 10s 一次
# 输出: 时间,最高CPU温度,平均CPU温度,各核频率和,node RSS,chrome RSS,总RSS
out="$1"
echo "ts,max_c,avg_c,freq_sum_mhz,node_rss,chrome_rss,total_rss" > "$out"
while true; do
  ts=$(date +%H:%M:%S)
  # CPU 温度（排除 pm7550ba 等电流传感器）
  max=0; sum=0; cnt=0
  for z in /sys/class/thermal/thermal_zone*; do
    n=$(cat "$z/type" 2>/dev/null)
    case "$n" in
      cpu-*|cpuss-*)
        t=$(cat "$z/temp" 2>/dev/null)
        [ -z "$t" ] && continue
        t=$((t/1000))
        [ "$t" -gt "$max" ] && max=$t
        sum=$((sum+t)); cnt=$((cnt+1))
        ;;
    esac
  done
  avg=0
  [ "$cnt" -gt 0 ] && avg=$((sum/cnt))
  # CPU 频率总和
  fsum=0
  for c in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq; do
    [ -r "$c" ] && fsum=$((fsum + $(cat "$c")/1000))
  done
  # 内存
  node_rss=0; chrome_rss=0
  for d in /proc/[0-9]*; do
    [ -r "$d/statm" ] || continue
    cmd=$(tr '\0' ' ' < "$d/cmdline" 2>/dev/null) || continue
    [ -z "$cmd" ] && continue
    r=$(awk '{print int($2*4/1024)}' "$d/statm" 2>/dev/null)
    case "$cmd" in
      *dist/index.js*) node_rss=$((node_rss + ${r:-0})) ;;
      *chrome-linux*|*headless_shell*) chrome_rss=$((chrome_rss + ${r:-0})) ;;
    esac
  done
  echo "$ts,$max,$avg,$fsum,$node_rss,$chrome_rss,$((node_rss+chrome_rss))" >> "$out"
  sleep 10
done
