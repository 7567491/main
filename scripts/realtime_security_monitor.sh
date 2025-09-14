#!/bin/bash

# 实时安全监控系统
# 每小时04分和34分执行，检测最近30分钟的恶意活动
# 设计目标：将检测延迟从7小时降低到30分钟以内

LOG_DIR="/home/main/logs"
SECURITY_LOG="$LOG_DIR/realtime_security.log"
NGINX_LOG="/var/log/nginx/access.log"
TEMP_DIR="/tmp/realtime_security"
DATE=$(date '+%Y-%m-%d %H:%M:%S')
ALERT_THRESHOLD=50   # 单IP 30分钟内超过50次请求触发警报（从100降低到50）
MALICIOUS_THRESHOLD=5  # 单IP检测到恶意行为超过5次立即封禁

# 创建必要目录
mkdir -p "$LOG_DIR" "$TEMP_DIR"

# 记录执行开始
echo "[$DATE] === 实时安全监控开始 ===" >> "$SECURITY_LOG"

# 获取最近30分钟的时间范围
CURRENT_TIME=$(date '+%d/%b/%Y:%H:%M')
THIRTY_MIN_AGO=$(date -d '30 minutes ago' '+%d/%b/%Y:%H:%M')

# 恶意行为特征模式（与主安全脚本保持一致）
declare -A MALICIOUS_PATTERNS=(
    ["敏感文件扫描"]="\.env|\.git/|wp-config\.php|config\.php|\.htaccess"
    ["目录遍历"]="%2e%2e|\.\./|/\.\./|\.\.%2f"
    ["PHP漏洞"]="phpinfo|eval-stdin\.php|test\.php|shell\.php"
    ["代码注入"]="allow_url_include|php://input|base64_decode"
    ["恶意工具UA"]="Go-http-client|zgrab|nmap|sqlmap|masscan"
)

# 提取最近30分钟的日志
echo "[$DATE] 分析时间范围: $THIRTY_MIN_AGO 到 $CURRENT_TIME" >> "$SECURITY_LOG"

# 使用awk提取最近30分钟的日志（更精确的时间过滤）
awk -v start="$THIRTY_MIN_AGO" -v end="$CURRENT_TIME" '
BEGIN {
    # 将时间转换为分钟数进行比较
    split(start, s, /[\/:]/)
    split(end, e, /[\/:]/)
    start_min = s[4]*60 + s[5]
    end_min = e[4]*60 + e[5]
}
{
    if (match($0, /([0-9]{2})\/([A-Za-z]{3})\/([0-9]{4}):([0-9]{2}):([0-9]{2})/, time_arr)) {
        current_min = time_arr[4]*60 + time_arr[5]
        if (current_min >= start_min && current_min <= end_min) {
            print $0
        }
    }
}' "$NGINX_LOG" > "$TEMP_DIR/recent_30min.log"

RECENT_REQUESTS=$(wc -l < "$TEMP_DIR/recent_30min.log")
echo "[$DATE] 最近30分钟共有 $RECENT_REQUESTS 个请求" >> "$SECURITY_LOG"

# 如果请求数为0，跳过检查
if [ "$RECENT_REQUESTS" -eq 0 ]; then
    echo "[$DATE] 无新请求，跳过检查" >> "$SECURITY_LOG"
    exit 0
fi

# 检查单IP高频访问（可能的DDoS或扫描）
echo "[$DATE] 检查高频访问IP..." >> "$SECURITY_LOG"
cut -d' ' -f1 "$TEMP_DIR/recent_30min.log" | sort | uniq -c | sort -nr | head -10 > "$TEMP_DIR/ip_frequency.txt"

# 检查是否有IP超过阈值
while read count ip; do
    if [ "$count" -gt "$ALERT_THRESHOLD" ]; then
        echo "[$DATE] 🚨 检测到高频访问IP: $ip ($count 次/30分钟)" >> "$SECURITY_LOG"
        
        # 检查该IP是否已被封禁
        if ! sudo iptables -L INPUT -n | grep -q "$ip"; then
            echo "[$DATE] 自动封禁高频访问IP: $ip" >> "$SECURITY_LOG"
            /home/main/scripts/security_manager.sh ban "$ip" >> "$SECURITY_LOG" 2>&1
        fi
    fi
done < "$TEMP_DIR/ip_frequency.txt"

# 检查恶意行为模式
echo "[$DATE] 检查恶意行为模式..." >> "$SECURITY_LOG"
> "$TEMP_DIR/malicious_ips.txt"

for pattern_name in "${!MALICIOUS_PATTERNS[@]}"; do
    pattern="${MALICIOUS_PATTERNS[$pattern_name]}"
    
    # 查找匹配恶意模式的请求
    grep -E "$pattern" "$TEMP_DIR/recent_30min.log" | cut -d' ' -f1 | sort -u >> "$TEMP_DIR/malicious_ips.txt"
done

# 处理检测到的恶意IP
if [ -s "$TEMP_DIR/malicious_ips.txt" ]; then
    sort -u "$TEMP_DIR/malicious_ips.txt" > "$TEMP_DIR/unique_malicious_ips.txt"
    
    while read ip; do
        # 统计该IP的恶意行为次数
        malicious_count=$(grep "$ip" "$TEMP_DIR/recent_30min.log" | grep -E -c "\.env|wp-admin|config\.php|phpinfo|base64|eval|admin|login")
        echo "[$DATE] 🚨 检测到恶意行为IP: $ip (恶意请求数: $malicious_count)" >> "$SECURITY_LOG"
        
        # 显示该IP的恶意请求样本
        echo "[$DATE] $ip 的恶意请求样本:" >> "$SECURITY_LOG"
        grep "$ip" "$TEMP_DIR/recent_30min.log" | grep -E "\.env|wp-admin|config\.php|phpinfo|base64|eval|admin|login" | head -3 >> "$SECURITY_LOG"
        
        # 检查该IP是否已被封禁
        if ! sudo iptables -L INPUT -n | grep -q "$ip"; then
            # 基于恶意行为次数决定是否封禁
            if [ "$malicious_count" -ge "$MALICIOUS_THRESHOLD" ]; then
                echo "[$DATE] 🔥 高风险恶意IP，立即封禁: $ip (恶意行为 $malicious_count 次)" >> "$SECURITY_LOG"
                /home/main/scripts/security_manager.sh ban "$ip" >> "$SECURITY_LOG" 2>&1
            else
                echo "[$DATE] ⚠️ 检测到恶意行为但未达到封禁阈值: $ip (恶意行为 $malicious_count 次，阈值 $MALICIOUS_THRESHOLD)" >> "$SECURITY_LOG"
            fi
        else
            echo "[$DATE] IP $ip 已在黑名单中" >> "$SECURITY_LOG"
        fi
    done < "$TEMP_DIR/unique_malicious_ips.txt"
else
    echo "[$DATE] ✅ 未检测到恶意行为" >> "$SECURITY_LOG"
fi

# 清理临时文件
rm -rf "$TEMP_DIR"

echo "[$DATE] === 实时安全监控完成 ===" >> "$SECURITY_LOG"