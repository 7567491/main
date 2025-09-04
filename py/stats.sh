#!/bin/bash

# 访问统计日志处理脚本 - main用户版本
LOG_DIR="/home/main/log"
NGINX_LOG="/var/log/nginx/access.log"
TIMESTAMP=$(date +"%Y%m%d_%H%M")
OUTPUT_FILE="$LOG_DIR/stats_$TIMESTAMP.json"

# 确保日志目录存在
mkdir -p "$LOG_DIR"

# 生成过去24小时数据
echo "生成24小时访问统计..." > "$LOG_DIR/process.log"

# 提取主页访问记录并统计每小时访问量
cat "$NGINX_LOG" /var/log/nginx/access.log.1 2>/dev/null | \
grep -E "GET / HTTP" | \
awk '{print $4}' | \
sed 's/\[//g' | \
cut -d: -f2 | \
sort -n | \
uniq -c > /tmp/hourly_raw.txt

# 生成JSON格式数据
echo '{"hourly_data":[' > "$OUTPUT_FILE"

total=0
peak_count=0
peak_hour=0

for hour in {0..23}; do
    count=$(grep -E "^\s*[0-9]+\s+$(printf "%02d" $hour)$" /tmp/hourly_raw.txt | awk '{print $1}')
    [[ -z "$count" ]] && count=0
    
    total=$((total + count))
    
    if [[ $count -gt $peak_count ]]; then
        peak_count=$count
        peak_hour=$hour
    fi
    
    if [[ $hour -eq 23 ]]; then
        echo "{\"hour\":$hour,\"count\":$count}" >> "$OUTPUT_FILE"
    else
        echo "{\"hour\":$hour,\"count\":$count}," >> "$OUTPUT_FILE"
    fi
done

avg=$((total / 24))

cat >> "$OUTPUT_FILE" << EOF
],
"summary":{
"total_visits":$total,
"peak_hour":"$(printf "%02d:00" $peak_hour)",
"avg_hourly":$avg,
"last_update":"$(date '+%Y-%m-%d %H:%M')"
},
"timestamp":"$TIMESTAMP"
}
EOF

# 清理旧日志文件(保留最近10个)
ls -t "$LOG_DIR"/stats_*.json 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true

# 清理临时文件
rm -f /tmp/hourly_raw.txt

# 同步到www存储桶的log目录
cp "$OUTPUT_FILE" "/mnt/www/log/" 2>/dev/null || true

echo "$(date): Stats generated - $OUTPUT_FILE, Total: $total visits" >> "$LOG_DIR/process.log"