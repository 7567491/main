#!/bin/bash

# 增强版访问统计脚本 - 支持24小时+7天统计
LOG_DIR="/home/main/logs"
NGINX_LOG="/var/log/nginx/access.log"
TIMESTAMP=$(date +"%Y%m%d_%H%M")
OUTPUT_FILE="$LOG_DIR/stats_$TIMESTAMP.json"

# 确保日志目录存在
mkdir -p "$LOG_DIR"

echo "生成7天+24小时访问统计..." > "$LOG_DIR/process.log"

# === 24小时每小时统计（从当前时间往前推24小时） ===
current_timestamp=$(date +%s)
start_timestamp=$((current_timestamp - 86400))  # 24小时前的时间戳

{
    cat "$NGINX_LOG" 2>/dev/null
    cat /var/log/nginx/access.log.1 2>/dev/null
} | grep -E "GET / HTTP" | \
awk -v start_ts="$start_timestamp" -v current_ts="$current_timestamp" '
{
    # 提取时间戳 [dd/Mon/yyyy:hh:mm:ss +timezone]
    if (match($4, /\[([0-9]{2})\/([A-Za-z]{3})\/([0-9]{4}):([0-9]{2}):([0-9]{2}):([0-9]{2})/, time_match)) {
        day = time_match[1]
        month = time_match[2]
        year = time_match[3]
        hour = time_match[4]
        min = time_match[5]
        sec = time_match[6]
        
        # 转换月份为数字
        months["Jan"] = 1; months["Feb"] = 2; months["Mar"] = 3; months["Apr"] = 4
        months["May"] = 5; months["Jun"] = 6; months["Jul"] = 7; months["Aug"] = 8
        months["Sep"] = 9; months["Oct"] = 10; months["Nov"] = 11; months["Dec"] = 12
        
        month_num = months[month]
        
        # 构建时间戳（简化处理，按UTC计算）
        log_timestamp = mktime(year " " month_num " " day " " hour " " min " " sec)
        
        # 只统计过去24小时内的数据
        if (log_timestamp >= start_ts && log_timestamp <= current_ts) {
            hours[hour]++
        }
    }
}
END {
    for (i = 0; i < 24; i++) {
        printf "%d %02d\n", (hours[sprintf("%02d", i)] ? hours[sprintf("%02d", i)] : 0), i
    }
}' | sort -k2 -n > /tmp/hourly_raw.txt

# === 7天每日统计 ===
{
    cat "$NGINX_LOG" 2>/dev/null
    cat /var/log/nginx/access.log.1 2>/dev/null  
    # 尝试获取更多历史日志
    find /var/log/nginx/ -name "access.log*" -type f 2>/dev/null | while read logfile; do
        if [[ $logfile =~ \.gz$ ]]; then
            zcat "$logfile" 2>/dev/null | head -1000
        else
            cat "$logfile" 2>/dev/null | head -1000
        fi
    done
} | grep -E "GET / HTTP" | \
awk '
BEGIN {
    # 获取今天和过去6天的日期
    "date +%d/%b/%Y" | getline today
    for (i = 0; i < 7; i++) {
        cmd = "date -d \""i" days ago\" +\"%d/%b/%Y\""
        cmd | getline date
        dates[i] = date
        close(cmd)
        daily[date] = 0
    }
}
{
    # 提取日期 [dd/Mon/yyyy:hh:mm:ss +timezone]
    if (match($4, /\[([0-9]{2}\/[A-Za-z]{3}\/[0-9]{4}):/, date_match)) {
        date = date_match[1]
        # 只统计过去7天的数据
        for (d in daily) {
            if (date == d) {
                daily[d]++
                break
            }
        }
    }
}
END {
    for (i = 6; i >= 0; i--) {
        date = dates[i]
        count = daily[date] ? daily[date] : 0
        printf "%s %d\n", date, count
    }
}' > /tmp/daily_raw.txt

# 开始生成JSON
echo '{' > "$OUTPUT_FILE"

# === 24小时数据 ===
echo '"hourly_data":[' >> "$OUTPUT_FILE"

total_24h=0
peak_count=0
peak_hour=0
current_hour=$(date '+%H' | sed 's/^0*//')

# 先计算统计数据
for hour in {0..23}; do
    count=$(awk -v h="$(printf "%02d" $hour)" '$2 == h {print $1}' /tmp/hourly_raw.txt)
    [[ -z "$count" ]] && count=0
    
    total_24h=$((total_24h + count))
    
    if [[ $count -gt $peak_count ]]; then
        peak_count=$count
        peak_hour=$hour
    fi
done

# 按从24小时前到上一个小时的时间顺序输出
for i in {23..0}; do
    hour=$(((current_hour - i + 24) % 24))
    count=$(awk -v h="$(printf "%02d" $hour)" '$2 == h {print $1}' /tmp/hourly_raw.txt)
    [[ -z "$count" ]] && count=0
    
    if [[ $i -eq 0 ]]; then
        echo "{\"hour\":$hour,\"count\":$count}" >> "$OUTPUT_FILE"
    else
        echo "{\"hour\":$hour,\"count\":$count}," >> "$OUTPUT_FILE"
    fi
done

echo '],' >> "$OUTPUT_FILE"

# === 7天数据 ===
echo '"daily_data":[' >> "$OUTPUT_FILE"

total_7d=0
day_count=0

while read -r date count; do
    total_7d=$((total_7d + count))
    
    # 转换日期格式为更友好的显示
    month_day=$(echo "$date" | awk -F'/' '{print $1"/"$2}')
    weekday=$(date -d "$date" "+%a" 2>/dev/null || echo "")
    
    if [[ $day_count -eq 6 ]]; then
        echo "{\"date\":\"$date\",\"label\":\"$month_day $weekday\",\"count\":$count}" >> "$OUTPUT_FILE"
    else
        echo "{\"date\":\"$date\",\"label\":\"$month_day $weekday\",\"count\":$count}," >> "$OUTPUT_FILE"
    fi
    
    ((day_count++))
done < /tmp/daily_raw.txt

echo '],' >> "$OUTPUT_FILE"

# === 汇总数据 ===
avg_24h=$((total_24h / 24))
avg_7d=$((total_7d / 7))
current_hour_visits=$(awk -v h="$(date '+%H')" '$2 == h {print $1}' /tmp/hourly_raw.txt | head -1)
[[ -z "$current_hour_visits" ]] && current_hour_visits=0

# 获取增长趋势
today_visits=$(head -1 /tmp/daily_raw.txt | awk '{print $2}')
yesterday_visits=$(sed -n '2p' /tmp/daily_raw.txt | awk '{print $2}')
if [[ $yesterday_visits -gt 0 ]]; then
    growth=$((((today_visits - yesterday_visits) * 100) / yesterday_visits))
    if [[ $growth -gt 0 ]]; then
        growth_text="+${growth}%"
    else
        growth_text="${growth}%"
    fi
else
    growth_text="新增"
fi

cat >> "$OUTPUT_FILE" << EOF
"summary":{
"total_visits_24h":$total_24h,
"total_visits_7d":$total_7d,
"peak_hour":"$(printf "%02d:00" $peak_hour)",
"peak_count":$peak_count,
"avg_hourly":$avg_24h,
"avg_daily":$avg_7d,
"current_hour":"$(date '+%H')",
"current_hour_visits":$current_hour_visits,
"today_visits":$today_visits,
"yesterday_visits":$yesterday_visits,
"growth_trend":"$growth_text",
"last_update":"$(date '+%Y-%m-%d %H:%M')",
"period":"过去7天+24小时"
},
"timestamp":"$TIMESTAMP"
}
EOF

# 清理旧日志文件(保留最近15个)
ls -t "$LOG_DIR"/stats_*.json 2>/dev/null | tail -n +16 | xargs rm -f 2>/dev/null || true

# 清理临时文件
rm -f /tmp/hourly_raw.txt /tmp/daily_raw.txt

# 同步到www存储桶的log目录
mkdir -p "/mnt/www/log/" 2>/dev/null || true
cp "$OUTPUT_FILE" "/mnt/www/log/" 2>/dev/null || true

echo "$(date): Enhanced stats generated - $OUTPUT_FILE" >> "$LOG_DIR/process.log"
echo "  24h total: $total_24h visits, 7d total: $total_7d visits" >> "$LOG_DIR/process.log"