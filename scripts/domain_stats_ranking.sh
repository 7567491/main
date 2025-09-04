#!/bin/bash

# 全域名访问量统计和排行脚本
# 功能：动态发现所有二级域名，统计过去7天访问量，生成排行榜
# 执行频率：每小时执行一次

LOG_DIR="/var/log/nginx"
TARGET_DIR="/mnt/www/webclick"
TIMESTAMP=$(date '+%Y%m%d_%H%M')
CURRENT_HOUR=$(date '+%H')

# 生成过去7天的日期模式
declare -a DATE_PATTERNS
for i in {0..6}; do
    day_pattern=$(date -d "$i days ago" '+%d/%b/%Y')
    DATE_PATTERNS+=("$day_pattern")
done

# 确保目标目录存在
mkdir -p "$TARGET_DIR"

# 创建统计日期范围的AWK模式
DATE_PATTERN_AWK=""
for pattern in "${DATE_PATTERNS[@]}"; do
    if [[ -n "$DATE_PATTERN_AWK" ]]; then
        DATE_PATTERN_AWK="$DATE_PATTERN_AWK|"
    fi
    DATE_PATTERN_AWK="$DATE_PATTERN_AWK$pattern"
done

echo "开始全域名访问量统计 - $(date)"
echo "统计时间范围: 过去7天"
echo "日期范围: ${DATE_PATTERNS[6]} 至 ${DATE_PATTERNS[0]}"

# 统计主域名访问量的函数
count_main_domain_visits() {
    local log_pattern="$1"
    local total_count=0
    
    # 处理当前日志文件
    if [[ -f "$LOG_DIR/access.log" ]]; then
        count=$(awk -v patterns="$DATE_PATTERN_AWK" '
        BEGIN { count = 0; split(patterns, date_arr, "|") }
        {
            match($0, /"[A-Z]+ ([^ ]+) HTTP/, path_arr)
            if (path_arr[1] ~ /^\/app/) {
                for (i in date_arr) {
                    if (index($0, date_arr[i]) > 0) {
                        count++
                        break
                    }
                }
            }
        }
        END { print count }
        ' "$LOG_DIR/access.log")
        total_count=$((total_count + count))
    fi
    
    # 处理轮转的日志文件（.1, .2, .3等）
    for i in {1..7}; do
        if [[ -f "$LOG_DIR/access.log.$i" ]]; then
            count=$(awk -v patterns="$DATE_PATTERN_AWK" '
            BEGIN { count = 0; split(patterns, date_arr, "|") }
            {
                match($0, /"[A-Z]+ ([^ ]+) HTTP/, path_arr)
                if (path_arr[1] ~ /^\/app/) {
                    for (j in date_arr) {
                        if (index($0, date_arr[j]) > 0) {
                            count++
                            break
                        }
                    }
                }
            }
            END { print count }
            ' "$LOG_DIR/access.log.$i")
            total_count=$((total_count + count))
        fi
        
        # 处理压缩的日志文件
        if [[ -f "$LOG_DIR/access.log.$i.gz" ]]; then
            count=$(zcat "$LOG_DIR/access.log.$i.gz" | awk -v patterns="$DATE_PATTERN_AWK" '
            BEGIN { count = 0; split(patterns, date_arr, "|") }
            {
                match($0, /"[A-Z]+ ([^ ]+) HTTP/, path_arr)
                if (path_arr[1] ~ /^\/app/) {
                    for (j in date_arr) {
                        if (index($0, date_arr[j]) > 0) {
                            count++
                            break
                        }
                    }
                }
            }
            END { print count }')
            total_count=$((total_count + count))
        fi
    done
    
    echo $total_count
}

# 统计二级域名访问量的函数  
count_subdomain_visits() {
    local domain_name="$1"
    local total_count=0
    
    # 处理当前日志文件
    log_file="$LOG_DIR/${domain_name}.access.log"
    if [[ -f "$log_file" ]]; then
        count=$(awk -v patterns="$DATE_PATTERN_AWK" '
        BEGIN { count = 0; split(patterns, date_arr, "|") }
        {
            for (i in date_arr) {
                if (index($0, date_arr[i]) > 0) {
                    count++
                    break
                }
            }
        }
        END { print count }
        ' "$log_file")
        total_count=$((total_count + count))
    fi
    
    # 处理轮转的日志文件
    for i in {1..7}; do
        if [[ -f "${log_file}.$i" ]]; then
            count=$(awk -v patterns="$DATE_PATTERN_AWK" '
            BEGIN { count = 0; split(patterns, date_arr, "|") }
            {
                for (j in date_arr) {
                    if (index($0, date_arr[j]) > 0) {
                        count++
                        break
                    }
                }
            }
            END { print count }
            ' "${log_file}.$i")
            total_count=$((total_count + count))
        fi
        
        # 处理压缩的日志文件
        if [[ -f "${log_file}.$i.gz" ]]; then
            count=$(zcat "${log_file}.$i.gz" | awk -v patterns="$DATE_PATTERN_AWK" '
            BEGIN { count = 0; split(patterns, date_arr, "|") }
            {
                for (j in date_arr) {
                    if (index($0, date_arr[j]) > 0) {
                        count++
                        break
                    }
                }
            }
            END { print count }')
            total_count=$((total_count + count))
        fi
    done
    
    echo $total_count
}

# 动态发现所有二级域名日志文件
declare -A domain_stats
domain_count=0

echo "发现的域名日志文件："

# 1. 处理pr.linapp.fun (AI内容生成工具) 
if [[ -f "$LOG_DIR/pr.linapp.fun.access.log" ]] || [[ -f "$LOG_DIR/access.log" ]]; then
    echo "  - AI工具域名: pr.linapp.fun"
    
    # 先尝试从独立日志文件统计
    pr_count=$(count_subdomain_visits "pr.linapp.fun")
    
    # 如果独立日志没有数据，从主日志中提取/app路径访问
    if [[ $pr_count -eq 0 ]]; then
        echo "    (从主域名/app路径统计)"
        pr_count=$(count_main_domain_visits)
    fi
    
    # 从配置文件获取pr域名信息
    pr_display_name=$(/home/main/scripts/get_domain_config.py display_name "pr.linapp.fun")
    domain_stats["pr|pr.linapp.fun|$pr_display_name"]="$pr_count"
    ((domain_count++))
fi

# 2. 处理所有二级域名
for log_file in $(find "$LOG_DIR" -name "*.linapp.fun.access.log" 2>/dev/null | sort); do
    if [[ -f "$log_file" ]]; then
        domain_name=$(basename "$log_file" .access.log)
        echo "  - 二级域名: $domain_name"
        
        # 统计过去7天访问量
        visit_count=$(count_subdomain_visits "$domain_name")
        
        # 从配置文件获取域名显示信息
        display_name=$(/home/main/scripts/get_domain_config.py display_name "$domain_name")
        
        # 检查域名是否被禁用
        if [[ "$display_name" == "DISABLED" ]]; then
            echo "    (已禁用，跳过)"
            continue
        fi
        
        domain_stats["${domain_name%%.*}|$domain_name|$display_name"]="$visit_count"
        ((domain_count++))
    fi
done

echo ""
echo "统计完成，共发现 $domain_count 个域名"
echo ""

# 按访问量排序
echo "按访问量排行："
echo "排名 | 域名 | 7天访问量"
echo "----|------|----------"

# 创建临时文件进行排序
temp_file="/tmp/domain_ranking_$$.txt"
> "$temp_file"

for key in "${!domain_stats[@]}"; do
    count="${domain_stats[$key]}"
    echo "$count|$key" >> "$temp_file"
done

# 按访问量降序排序
sort -t'|' -k1,1nr "$temp_file" > "${temp_file}_sorted"

# 生成排行榜和JSON文件
ranking_file="$TARGET_DIR/ranking_${TIMESTAMP}.json"
echo "{" > "$ranking_file"
echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"," >> "$ranking_file"
echo "  \"period\": \"7d\"," >> "$ranking_file"
echo "  \"total_domains\": $domain_count," >> "$ranking_file"
echo "  \"ranking\": [" >> "$ranking_file"

rank=1
first=true

while IFS='|' read -r count short_name full_domain display_name; do
    printf "%2d   | %-20s | %8s\n" "$rank" "$display_name" "$count"
    
    # 添加到JSON
    if [[ "$first" == "true" ]]; then
        first=false
    else
        echo "    ," >> "$ranking_file"
    fi
    
    echo "    {" >> "$ranking_file"
    echo "      \"rank\": $rank," >> "$ranking_file"
    echo "      \"short_name\": \"$short_name\"," >> "$ranking_file"
    echo "      \"domain\": \"$full_domain\"," >> "$ranking_file"
    echo "      \"display_name\": \"$display_name\"," >> "$ranking_file"
    echo "      \"visits_7d\": $count" >> "$ranking_file"
    echo -n "    }" >> "$ranking_file"
    
    ((rank++))
done < "${temp_file}_sorted"

echo "" >> "$ranking_file"
echo "  ]" >> "$ranking_file"
echo "}" >> "$ranking_file"

echo ""
echo "排行榜已保存到: $ranking_file"

# 生成专门的Top7文件供主页使用
top7_file="$TARGET_DIR/top7_${TIMESTAMP}.json"
echo "{" > "$top7_file"
echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"," >> "$top7_file"
echo "  \"last_update\": \"$(date '+%Y-%m-%d %H:%M')\"," >> "$top7_file"
echo "  \"period\": \"7d\"," >> "$top7_file"
echo "  \"top7\": [" >> "$top7_file"

rank=1
first=true

while IFS='|' read -r count short_name full_domain display_name && [[ $rank -le 7 ]]; do
    if [[ "$first" == "true" ]]; then
        first=false
    else
        echo "    ," >> "$top7_file"
    fi
    
    echo "    {" >> "$top7_file"
    echo "      \"rank\": $rank," >> "$top7_file"
    echo "      \"short_name\": \"$short_name\"," >> "$top7_file"
    echo "      \"domain\": \"$full_domain\"," >> "$top7_file"
    echo "      \"display_name\": \"$display_name\"," >> "$top7_file"
    echo "      \"visits_7d\": $count," >> "$top7_file"
    echo "      \"url\": \"$(if [[ $full_domain == *"/app"* ]]; then echo "/app"; else echo "https://$full_domain"; fi)\"" >> "$top7_file"
    echo -n "    }" >> "$top7_file"
    
    ((rank++))
done < "${temp_file}_sorted"

echo "" >> "$top7_file"
echo "  ]" >> "$top7_file"
echo "}" >> "$top7_file"

echo "Top7文件已保存到: $top7_file"

# 创建latest链接指向最新文件
ln -sf "ranking_${TIMESTAMP}.json" "$TARGET_DIR/latest_ranking.json"
ln -sf "top7_${TIMESTAMP}.json" "$TARGET_DIR/latest_top7.json"

# 清理临时文件
rm -f "$temp_file" "${temp_file}_sorted"

# 清理7天前的旧文件
find "$TARGET_DIR" -name "ranking_*.json" -mtime +7 -delete 2>/dev/null
find "$TARGET_DIR" -name "top7_*.json" -mtime +7 -delete 2>/dev/null

echo ""
echo "统计完成 - $(date)"
echo "最新数据: latest_ranking.json, latest_top7.json"
echo "---"