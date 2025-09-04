#!/bin/bash

# 智能恶意IP检测和封禁系统
# 每日凌晨4点自动执行，检测和封禁恶意IP

LOG_DIR="/home/main/logs"
SECURITY_LOG="$LOG_DIR/security_scan.log"
BANNED_IPS_LOG="$LOG_DIR/banned_ips.log"
NGINX_LOG="/var/log/nginx/access.log"
TEMP_DIR="/tmp/security_scan"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# 创建必要目录
mkdir -p "$LOG_DIR" "$TEMP_DIR"

# 记录执行开始
echo "[$DATE] === 开始恶意IP扫描和封禁 ===" >> "$SECURITY_LOG"

# 定义恶意行为特征模式
declare -A MALICIOUS_PATTERNS=(
    ["路径遍历"]="\.git/|\.env|/config/|/vendor/|%2e%2e|\.\./\.\./|\.\.%2f"
    ["PHP漏洞扫描"]="phpinfo|test\.php|eval-stdin\.php|php-info\.php|info\.php"
    ["代码注入"]="allow_url_include|auto_prepend_file|php://input|base64_decode|eval\("
    ["目录遍历"]="cgi-bin/\.\.%2f|cgi-bin/\.\./"
    ["WordPress扫描"]="wp-admin|xmlrpc\.php|wp-includes|wp-content|wp-login"
    ["系统探测"]="/etc/passwd|/proc/|/sys/|/usr/bin|/bin/sh"
    ["数据库探测"]="phpmyadmin|phpMyAdmin|adminer|mysql|postgresql"
    ["恶意工具UA"]="Go-http-client|libredtail|zgrab|masscan|nmap|sqlmap|nikto"
)

# 检查昨天的日志（避免检查太久远的日志影响性能）
YESTERDAY=$(date -d "yesterday" '+%d/%b/%Y')
TODAY=$(date '+%d/%b/%Y')

echo "[$DATE] 分析日期范围: $YESTERDAY 和 $TODAY" >> "$SECURITY_LOG"

# 提取最近24小时的访问日志
grep -E "($YESTERDAY|$TODAY)" "$NGINX_LOG" > "$TEMP_DIR/recent_logs.txt"

# 分析各类恶意行为
echo "[$DATE] 开始恶意行为模式分析..." >> "$SECURITY_LOG"

# 存储可疑IP
> "$TEMP_DIR/suspicious_ips.txt"

for pattern_name in "${!MALICIOUS_PATTERNS[@]}"; do
    pattern="${MALICIOUS_PATTERNS[$pattern_name]}"
    echo "[$DATE] 检测 $pattern_name 模式..." >> "$SECURITY_LOG"
    
    # 查找匹配恶意模式的IP
    grep -iE "$pattern" "$TEMP_DIR/recent_logs.txt" | \
    awk '{print $1}' | \
    sort | uniq -c | \
    awk -v pattern="$pattern_name" '$1 >= 3 {print $2 ":" pattern ":" $1}' >> "$TEMP_DIR/suspicious_ips.txt"
done

# 检测高频404/400错误（可能是扫描行为）
echo "[$DATE] 检测高频错误访问..." >> "$SECURITY_LOG"
grep -E " (400|404|403|500) " "$TEMP_DIR/recent_logs.txt" | \
awk '{print $1}' | \
sort | uniq -c | \
awk '$1 >= 20 {print $2 ":高频错误:" $1}' >> "$TEMP_DIR/suspicious_ips.txt"

# 检测异常User-Agent
echo "[$DATE] 检测异常User-Agent..." >> "$SECURITY_LOG"
grep -iE "(Go-http-client|libredtail|zgrab|masscan|nmap|sqlmap|nikto|python|wget|curl)" "$TEMP_DIR/recent_logs.txt" | \
awk '{print $1}' | \
sort | uniq -c | \
awk '$1 >= 5 {print $2 ":恶意工具:" $1}' >> "$TEMP_DIR/suspicious_ips.txt"

# 统计和去重可疑IP
if [ -s "$TEMP_DIR/suspicious_ips.txt" ]; then
    echo "[$DATE] 发现可疑IP活动:" >> "$SECURITY_LOG"
    cat "$TEMP_DIR/suspicious_ips.txt" >> "$SECURITY_LOG"
    
    # 提取IP地址并去重
    cut -d':' -f1 "$TEMP_DIR/suspicious_ips.txt" | sort | uniq > "$TEMP_DIR/unique_malicious_ips.txt"
    
    # 检查是否已被封禁，避免重复封禁
    > "$TEMP_DIR/new_bans.txt"
    
    while read -r ip; do
        if ! iptables -L INPUT -n | grep -q "$ip"; then
            # 排除内网IP和正常的CDN/云服务商IP（可根据需要调整）
            if [[ ! "$ip" =~ ^(10\.|172\.1[6-9]\.|172\.2[0-9]\.|172\.3[0-1]\.|192\.168\.|127\.) ]]; then
                echo "$ip" >> "$TEMP_DIR/new_bans.txt"
            fi
        fi
    done < "$TEMP_DIR/unique_malicious_ips.txt"
    
    # 执行封禁
    if [ -s "$TEMP_DIR/new_bans.txt" ]; then
        ban_count=0
        while read -r ip; do
            # 执行iptables封禁
            if sudo iptables -I INPUT -s "$ip" -j DROP; then
                echo "[$DATE] 成功封禁恶意IP: $ip" >> "$SECURITY_LOG"
                echo "[$DATE] $ip - 恶意行为检测封禁" >> "$BANNED_IPS_LOG"
                ((ban_count++))
            else
                echo "[$DATE] 封禁失败: $ip" >> "$SECURITY_LOG"
            fi
        done < "$TEMP_DIR/new_bans.txt"
        
        if [ $ban_count -gt 0 ]; then
            # 保存iptables规则
            sudo iptables-save > /tmp/iptables_rules_backup_$(date +%Y%m%d_%H%M%S).rules
            echo "[$DATE] 本次共封禁 $ban_count 个恶意IP" >> "$SECURITY_LOG"
            
            # 发送简单通知到系统日志
            logger "Security: 封禁了 $ban_count 个恶意IP"
        fi
    else
        echo "[$DATE] 没有新的IP需要封禁" >> "$SECURITY_LOG"
    fi
else
    echo "[$DATE] 未发现可疑IP活动" >> "$SECURITY_LOG"
fi

# 清理临时文件
rm -rf "$TEMP_DIR"

# 清理旧日志（保留30天）
find "$LOG_DIR" -name "security_scan.log" -mtime +30 -delete 2>/dev/null
find "$LOG_DIR" -name "banned_ips.log" -mtime +30 -delete 2>/dev/null

echo "[$DATE] === 恶意IP扫描完成 ===" >> "$SECURITY_LOG"
echo "" >> "$SECURITY_LOG"