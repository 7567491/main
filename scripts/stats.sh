#!/bin/bash

# 访问统计日志处理脚本 - main用户版本
LOG_DIR="/home/main/logs"
NGINX_LOG="/var/log/nginx/access.log"
TIMESTAMP=$(date +"%Y%m%d_%H%M")
OUTPUT_FILE="$LOG_DIR/stats_$TIMESTAMP.json"

# 确保日志目录存在
mkdir -p "$LOG_DIR"

# 生成过去24小时数据
echo "生成24小时访问统计..." > "$LOG_DIR/process.log"

# 提取过去24小时的访问记录并按小时统计
{
    cat "$NGINX_LOG" 2>/dev/null
    cat /var/log/nginx/access.log.1 2>/dev/null
} | grep -E "GET / HTTP" | \
awk '
{
    # 提取时间戳中的小时 [dd/Mon/yyyy:hh:mm:ss +timezone]
    if (match($4, /[0-9]{2}\/[A-Za-z]{3}\/[0-9]{4}:([0-9]{2}):/, hour_match)) {
        hour = hour_match[1]
        hours[hour]++
    }
}
END {
    for (i = 0; i < 24; i++) {
        printf "%d %02d\n", (hours[sprintf("%02d", i)] ? hours[sprintf("%02d", i)] : 0), i
    }
}' | sort -k2 -n > /tmp/hourly_raw.txt

# 生成JSON格式数据
echo '{"hourly_data":[' > "$OUTPUT_FILE"

total=0
peak_count=0
peak_hour=0

for hour in {0..23}; do
    count=$(awk -v h="$(printf "%02d" $hour)" '$2 == h {print $1}' /tmp/hourly_raw.txt)
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
"peak_count":$peak_count,
"avg_hourly":$avg,
"current_hour":"$(date '+%H')",
"current_hour_visits":$(awk -v h="$(date '+%H')" '$2 == h {print $1}' /tmp/hourly_raw.txt | head -1),
"last_update":"$(date '+%Y-%m-%d %H:%M')",
"period":"过去24小时"
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