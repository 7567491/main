#!/bin/bash

# 二级域名访问量日志同步脚本
# 功能：从nginx日志提取相关域名访问信息，推送到webclick目录
# 执行频率：每小时执行一次

LOG_DIR="/var/log/nginx"
TARGET_DIR="/mnt/www/webclick"
TIMESTAMP=$(date '+%Y%m%d_%H%M')

# 确保目标目录存在
mkdir -p "$TARGET_DIR"

# 定义需要监控的域名（与主页6个卡片对应）
declare -A DOMAINS
DOMAINS[app]="linapp.fun /app"           # 主域名/app路径
DOMAINS[az]="az.linapp.fun"              # 数据分析
DOMAINS[didi]="didi.linapp.fun"          # 客户管理  
DOMAINS[pdf]="pdf.linapp.fun"            # PDF工具
DOMAINS[vote]="vote.linapp.fun"          # 投票系统
DOMAINS[meet]="meet.linapp.fun"          # 会议工具

# 获取过去24小时的时间范围
CURRENT_HOUR=$(date '+%H')
CURRENT_DAY=$(date '+%d/%b/%Y')
YESTERDAY=$(date -d "1 day ago" '+%d/%b/%Y')

echo "开始同步域名访问日志 - $(date)"

# 处理每个域名
for key in "${!DOMAINS[@]}"; do
    domain_info="${DOMAINS[$key]}"
    echo "处理域名: $key ($domain_info)"
    
    output_file="$TARGET_DIR/${key}_${TIMESTAMP}.log"
    
    if [[ "$key" == "app" ]]; then
        # 处理主域名下的/app路径
        if [[ -f "$LOG_DIR/access.log" ]]; then
            # 提取过去24小时/app路径的访问记录
            awk -v current_day="$CURRENT_DAY" -v yesterday="$YESTERDAY" '
            BEGIN { count = 0 }
            {
                # 提取时间戳和路径
                match($0, /\[([^\]]+)\]/, time_arr)
                match($0, /"[A-Z]+ ([^ ]+) HTTP/, path_arr)
                
                if (path_arr[1] ~ /^\/app/ && (index($0, current_day) > 0 || index($0, yesterday) > 0)) {
                    count++
                    print $0
                }
            }
            END { print "# 总访问量:", count > "/dev/stderr" }
            ' "$LOG_DIR/access.log" > "$output_file" 2>"$TARGET_DIR/${key}_count_${TIMESTAMP}.txt"
        fi
    else
        # 处理二级域名
        log_file="$LOG_DIR/${domain_info}.access.log"
        if [[ -f "$log_file" ]]; then
            # 提取过去24小时的访问记录
            awk -v current_day="$CURRENT_DAY" -v yesterday="$YESTERDAY" '
            BEGIN { count = 0 }
            {
                if (index($0, current_day) > 0 || index($0, yesterday) > 0) {
                    count++
                    print $0
                }
            }
            END { print "# 总访问量:", count > "/dev/stderr" }
            ' "$log_file" > "$output_file" 2>"$TARGET_DIR/${key}_count_${TIMESTAMP}.txt"
        else
            echo "日志文件不存在: $log_file" 
            echo "0" > "$TARGET_DIR/${key}_count_${TIMESTAMP}.txt"
        fi
    fi
    
    # 获取文件行数作为访问量
    if [[ -f "$output_file" ]]; then
        line_count=$(wc -l < "$output_file")
        echo "$line_count" > "$TARGET_DIR/${key}_count_${TIMESTAMP}.txt"
        echo "  - 提取了 $line_count 条访问记录"
    else
        echo "0" > "$TARGET_DIR/${key}_count_${TIMESTAMP}.txt"
        echo "  - 无访问记录"
    fi
done

# 生成汇总统计
echo "生成汇总统计..."
summary_file="$TARGET_DIR/summary_${TIMESTAMP}.json"

echo "{" > "$summary_file"
echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"," >> "$summary_file"
echo "  \"period\": \"24h\"," >> "$summary_file"
echo "  \"domains\": {" >> "$summary_file"

first=true
for key in "${!DOMAINS[@]}"; do
    count_file="$TARGET_DIR/${key}_count_${TIMESTAMP}.txt"
    count=0
    if [[ -f "$count_file" ]]; then
        count=$(cat "$count_file")
    fi
    
    if [[ "$first" == "true" ]]; then
        first=false
    else
        echo "    ," >> "$summary_file"
    fi
    
    echo "    \"$key\": {" >> "$summary_file"
    echo "      \"name\": \"$key\"," >> "$summary_file"
    echo "      \"domain\": \"${DOMAINS[$key]}\"," >> "$summary_file"
    echo "      \"visits_24h\": $count" >> "$summary_file"
    echo -n "    }" >> "$summary_file"
done

echo "" >> "$summary_file"
echo "  }" >> "$summary_file"
echo "}" >> "$summary_file"

echo "汇总统计已保存到: $summary_file"

# 清理7天前的旧文件
find "$TARGET_DIR" -name "*.log" -mtime +7 -delete 2>/dev/null
find "$TARGET_DIR" -name "*_count_*.txt" -mtime +7 -delete 2>/dev/null
find "$TARGET_DIR" -name "summary_*.json" -mtime +7 -delete 2>/dev/null

echo "日志同步完成 - $(date)"
echo "---"