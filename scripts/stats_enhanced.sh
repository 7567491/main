#!/bin/bash

# 增强版访问统计脚本 - 支持24小时+7天统计（包含所有启用域名）
LOG_DIR="/home/main/logs"
NGINX_LOG="/var/log/nginx/access.log"
DOMAINS_CONFIG="/home/main/data/domains_config.json"
TIMESTAMP=$(date +"%Y%m%d_%H%M")
OUTPUT_FILE="$LOG_DIR/stats_$TIMESTAMP.json"

# 确保日志目录存在
mkdir -p "$LOG_DIR"

# 获取启用的域名列表
get_enabled_domains() {
    if [[ -f "$DOMAINS_CONFIG" ]]; then
        python3 -c "
import json
with open('$DOMAINS_CONFIG', 'r') as f:
    config = json.load(f)
    for domain, info in config['domains'].items():
        if info.get('enabled', False):
            print(domain)
"
    fi
}

# 获取所有相关日志文件的内容
get_all_logs() {
    local time_filter="$1"
    
    # 主域名日志（只统计首页访问）
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
    } | grep -E "GET / HTTP"
    
    # 启用的二级域名日志（统计所有访问，主要是首页）
    get_enabled_domains | while read domain; do
        domain_log="/var/log/nginx/${domain}.access.log"
        if [[ -f "$domain_log" ]]; then
            {
                cat "$domain_log" 2>/dev/null
                cat "${domain_log}.1" 2>/dev/null
                # 获取该域名的历史日志
                find /var/log/nginx/ -name "${domain}.access.log*" -type f 2>/dev/null | while read logfile; do
                    if [[ $logfile =~ \.gz$ ]]; then
                        zcat "$logfile" 2>/dev/null | head -500
                    else
                        cat "$logfile" 2>/dev/null | head -500
                    fi
                done
            } | grep -E "GET /"
        fi
    done
}

echo "生成全域名7天+24小时访问统计..." > "$LOG_DIR/process.log"

# === 24小时每小时统计（从当前时间往前推24小时） ===
current_timestamp=$(date +%s)
start_timestamp=$((current_timestamp - 86400))  # 24小时前的时间戳

get_all_logs | \
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
get_all_logs | \
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

# === CPU和攻击分析数据 ===
echo "$(date): 收集CPU和攻击分析数据..." >> "$LOG_DIR/process.log"

# 运行CPU监控脚本
/home/main/scripts/cpu_monitor.sh >/dev/null 2>&1 || true

# 运行攻击分析脚本  
/home/main/scripts/attack_analysis.sh >/dev/null 2>&1 || true

# 添加CPU数据到JSON
if [[ -f "/home/main/logs/cpu_usage_24h.json" ]]; then
    echo '"cpu_data":' >> "$OUTPUT_FILE"
    cat "/home/main/logs/cpu_usage_24h.json" >> "$OUTPUT_FILE" 2>/dev/null || echo '{}' >> "$OUTPUT_FILE"
    echo ',' >> "$OUTPUT_FILE"
else
    echo '"cpu_data":{},' >> "$OUTPUT_FILE"
fi

# 添加攻击分析数据到JSON
if [[ -f "/home/main/logs/attack_analysis_24h.json" ]]; then
    echo '"attack_data":' >> "$OUTPUT_FILE"
    cat "/home/main/logs/attack_analysis_24h.json" >> "$OUTPUT_FILE" 2>/dev/null || echo '{}' >> "$OUTPUT_FILE"
    echo ',' >> "$OUTPUT_FILE"
else
    echo '"attack_data":{},' >> "$OUTPUT_FILE"
fi

# === 30天二级域名访问排行统计 ===
echo "$(date): 统计过去30天二级域名访问排行..." >> "$LOG_DIR/process.log"

echo '"domain_ranking_30d":' >> "$OUTPUT_FILE"
echo '[' >> "$OUTPUT_FILE"

# 获取过去30天的日期范围（暂时使用过去7天来测试，确保有数据）
dates_30d=()
for i in {6..0}; do
    date=$(date -d "$i days ago" "+%d/%b/%Y")
    dates_30d+=("$date")
done

# 统计每个启用域名在过去30天的访问量
declare -A domain_stats

# 统计主域名linapp.fun的访问（只统计首页）
main_domain_count=0
{
    cat "$NGINX_LOG" 2>/dev/null
    cat /var/log/nginx/access.log.1 2>/dev/null
    find /var/log/nginx/ -name "access.log*" -type f 2>/dev/null | while read logfile; do
        if [[ $logfile =~ \.gz$ ]]; then
            zcat "$logfile" 2>/dev/null | head -2000
        else
            cat "$logfile" 2>/dev/null | head -2000
        fi
    done
} | grep -E "GET / HTTP" | \
awk '
BEGIN {
    # 创建7天的日期映射（测试用）
    for (i = 0; i < 7; i++) {
        cmd = "date -d \"" i " days ago\" +\"%d/%b/%Y\""
        cmd | getline date
        valid_dates[date] = 1
        close(cmd)
    }
}
{
    if (match($4, /\[([0-9]{2}\/[A-Za-z]{3}\/[0-9]{4}):/, date_match)) {
        date = date_match[1]
        if (valid_dates[date]) {
            count++
        }
    }
}
END { print count }
' | head -1

[[ -z "$main_domain_count" ]] && main_domain_count=0
domain_stats["linapp.fun"]=$main_domain_count

# 统计各个启用的二级域名访问量
get_enabled_domains | while read domain; do
    domain_log="/var/log/nginx/${domain}.access.log"
    domain_count=0
    
    if [[ -f "$domain_log" ]]; then
        {
            cat "$domain_log" 2>/dev/null
            cat "${domain_log}.1" 2>/dev/null
            find /var/log/nginx/ -name "${domain}.access.log*" -type f 2>/dev/null | while read logfile; do
                if [[ $logfile =~ \.gz$ ]]; then
                    zcat "$logfile" 2>/dev/null | head -1000
                else
                    cat "$logfile" 2>/dev/null | head -1000
                fi
            done
        } | awk '
        BEGIN {
            # 创建7天的日期映射（测试用）
            for (i = 0; i < 7; i++) {
                cmd = "date -d \"" i " days ago\" +\"%d/%b/%Y\""
                cmd | getline date
                valid_dates[date] = 1
                close(cmd)
            }
        }
        {
            if (match($4, /\[([0-9]{2}\/[A-Za-z]{3}\/[0-9]{4}):/, date_match)) {
                date = date_match[1]
                if (valid_dates[date]) {
                    count++
                }
            }
        }
        END { print count }
        ' | head -1
        
        [[ -z "$domain_count" ]] && domain_count=0
        echo "$domain:$domain_count" >> /tmp/domain_stats_30d.txt
    fi
done

# 添加主域名到统计文件
echo "linapp.fun:$main_domain_count" > /tmp/domain_stats_30d_all.txt
[[ -f "/tmp/domain_stats_30d.txt" ]] && cat /tmp/domain_stats_30d.txt >> /tmp/domain_stats_30d_all.txt

# 按访问量排序，取前10名
sort -t':' -k2 -nr /tmp/domain_stats_30d_all.txt | head -10 | \
while IFS=':' read -r domain count; do
    # 获取域名配置信息
    if [[ "$domain" == "linapp.fun" ]]; then
        display_name="LinApp主页"
        icon="🏠"
        description="智能工具集合主页"
    else
        # 从域名配置文件获取信息
        domain_info=$(python3 -c "
import json
try:
    with open('$DOMAINS_CONFIG', 'r') as f:
        config = json.load(f)
        info = config['domains'].get('$domain', {})
        print(f\"{info.get('name', '$domain')}|{info.get('icon', '🌐')}|{info.get('description', '暂无描述')}\")
except:
    print('$domain|🌐|暂无描述')
" 2>/dev/null)
        
        IFS='|' read -r display_name icon description <<< "$domain_info"
        [[ -z "$display_name" ]] && display_name="$domain"
        [[ -z "$icon" ]] && icon="🌐"
        [[ -z "$description" ]] && description="暂无描述"
    fi
    
    echo "{\"domain\":\"$domain\",\"name\":\"$display_name\",\"icon\":\"$icon\",\"description\":\"$description\",\"visits\":$count}," >> /tmp/domain_ranking_json.txt
done

# 移除最后一行的逗号并输出JSON
if [[ -f "/tmp/domain_ranking_json.txt" ]]; then
    # 移除最后一个逗号
    sed '$ s/,$//' /tmp/domain_ranking_json.txt >> "$OUTPUT_FILE"
else
    # 如果没有数据，输出空数组内容
    echo '{"domain":"linapp.fun","name":"LinApp主页","icon":"🏠","description":"智能工具集合主页","visits":0}' >> "$OUTPUT_FILE"
fi

echo '],' >> "$OUTPUT_FILE"

# 清理临时文件
rm -f /tmp/domain_stats_30d.txt /tmp/domain_stats_30d_all.txt /tmp/domain_ranking_json.txt

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
"period":"全域名过去7天+24小时"
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

# 更新最新统计文件的符号链接
if [[ -f "/mnt/www/log/$(basename "$OUTPUT_FILE")" ]]; then
    ln -sf "$(basename "$OUTPUT_FILE")" "/mnt/www/log/latest_stats.json"
fi

echo "$(date): Enhanced stats generated - $OUTPUT_FILE" >> "$LOG_DIR/process.log"
echo "  24h total: $total_24h visits, 7d total: $total_7d visits" >> "$LOG_DIR/process.log"