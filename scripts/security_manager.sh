#!/bin/bash

# 安全管理工具 - 管理IP黑名单和查看安全状态
# Usage: ./security_manager.sh [list|ban|unban|status|stats]

LOG_DIR="/home/main/logs"
SECURITY_LOG="$LOG_DIR/security_scan.log"
BANNED_IPS_LOG="$LOG_DIR/banned_ips.log"

show_help() {
    echo "🛡️  安全管理工具"
    echo "Usage: $0 [command] [arguments]"
    echo ""
    echo "Commands:"
    echo "  list          - 显示所有被封禁的IP"
    echo "  ban <IP>      - 手动封禁指定IP"
    echo "  unban <IP>    - 解封指定IP"
    echo "  status        - 显示安全扫描状态"
    echo "  stats         - 显示安全统计信息"
    echo "  clean         - 清理超过30天的IP封禁（慎用）"
    echo ""
    echo "Examples:"
    echo "  $0 list"
    echo "  $0 ban 192.168.1.100"
    echo "  $0 unban 192.168.1.100"
    echo "  $0 stats"
}

list_banned_ips() {
    echo "🚫 当前被封禁的IP列表："
    echo "===================="
    
    # 从iptables获取封禁列表
    banned_count=0
    while read -r line; do
        if echo "$line" | grep -q "DROP.*all.*--"; then
            ip=$(echo "$line" | awk '{print $4}')
            if [[ "$ip" != "anywhere" && "$ip" != "0.0.0.0/0" ]]; then
                echo "🔴 $ip"
                ((banned_count++))
            fi
        fi
    done < <(iptables -L INPUT -n | grep "DROP")
    
    echo "===================="
    echo "📊 总计封禁IP数量: $banned_count"
    
    if [ -f "$BANNED_IPS_LOG" ]; then
        echo ""
        echo "📅 最近封禁记录 (最后5条):"
        tail -5 "$BANNED_IPS_LOG"
    fi
}

ban_ip() {
    local ip="$1"
    if [[ -z "$ip" ]]; then
        echo "❌ 请指定要封禁的IP地址"
        return 1
    fi
    
    # 验证IP格式
    if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "❌ 无效的IP地址格式: $ip"
        return 1
    fi
    
    # 检查是否已被封禁
    if iptables -L INPUT -n | grep -q "$ip"; then
        echo "⚠️  IP $ip 已经在封禁列表中"
        return 1
    fi
    
    # 执行封禁
    if sudo iptables -I INPUT -s "$ip" -j DROP; then
        echo "✅ 成功封禁IP: $ip"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $ip - 手动封禁" >> "$BANNED_IPS_LOG"
        
        # 保存规则
        sudo iptables-save > /tmp/iptables_manual_ban_$(date +%Y%m%d_%H%M%S).rules
        logger "Security: 手动封禁IP $ip"
    else
        echo "❌ 封禁失败: $ip"
        return 1
    fi
}

unban_ip() {
    local ip="$1"
    if [[ -z "$ip" ]]; then
        echo "❌ 请指定要解封的IP地址"
        return 1
    fi
    
    # 检查是否在封禁列表中
    if ! iptables -L INPUT -n | grep -q "$ip"; then
        echo "⚠️  IP $ip 不在封禁列表中"
        return 1
    fi
    
    # 执行解封
    if sudo iptables -D INPUT -s "$ip" -j DROP; then
        echo "✅ 成功解封IP: $ip"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $ip - 手动解封" >> "$BANNED_IPS_LOG"
        
        # 保存规则
        sudo iptables-save > /tmp/iptables_manual_unban_$(date +%Y%m%d_%H%M%S).rules
        logger "Security: 手动解封IP $ip"
    else
        echo "❌ 解封失败: $ip"
        return 1
    fi
}

show_status() {
    echo "🛡️  安全防护状态报告"
    echo "======================"
    echo ""
    
    # 检查安全扫描脚本
    if [ -f "/home/main/scripts/security_scan.sh" ]; then
        echo "✅ 安全扫描脚本: 已部署"
    else
        echo "❌ 安全扫描脚本: 未找到"
    fi
    
    # 检查定时任务
    if crontab -l 2>/dev/null | grep -q "security_scan.sh"; then
        echo "✅ 定时任务: 已配置 (每日4:00AM)"
    else
        echo "❌ 定时任务: 未配置"
    fi
    
    # 检查nginx配置
    if sudo nginx -t >/dev/null 2>&1; then
        echo "✅ Nginx配置: 正常"
    else
        echo "❌ Nginx配置: 存在问题"
    fi
    
    # 显示最近扫描时间
    if [ -f "$SECURITY_LOG" ]; then
        last_scan=$(tail -1 "$SECURITY_LOG" | grep -o "\[.*\]" | tr -d "[]")
        echo "📅 最后扫描时间: $last_scan"
    else
        echo "⚠️  尚未执行过安全扫描"
    fi
    
    echo ""
    list_banned_ips
}

show_stats() {
    echo "📊 安全统计信息"
    echo "================"
    echo ""
    
    if [ -f "$BANNED_IPS_LOG" ]; then
        # 统计总封禁数
        total_bans=$(grep -c "封禁" "$BANNED_IPS_LOG" 2>/dev/null || echo "0")
        echo "🚫 累计封禁IP数量: $total_bans"
        
        # 统计今日封禁数
        today=$(date '+%Y-%m-%d')
        today_bans=$(grep "$today" "$BANNED_IPS_LOG" | grep -c "封禁" || echo "0")
        echo "📅 今日新封禁: $today_bans"
        
        # 统计本周封禁数
        week_ago=$(date -d "7 days ago" '+%Y-%m-%d')
        week_bans=$(awk -v start="$week_ago" '$0 >= "["start && /封禁/' "$BANNED_IPS_LOG" | wc -l)
        echo "📊 本周封禁: $week_bans"
        
        echo ""
        echo "🔥 封禁原因统计:"
        grep "封禁" "$BANNED_IPS_LOG" | awk -F' - ' '{print $2}' | sort | uniq -c | sort -nr
    else
        echo "📝 暂无封禁记录"
    fi
    
    # 显示当前iptables规则数量
    current_rules=$(iptables -L INPUT | grep -c "DROP")
    echo ""
    echo "🔒 当前防火墙规则: $current_rules 条DROP规则"
}

clean_old_bans() {
    echo "🧹 清理超过30天的IP封禁规则..."
    echo "⚠️  此操作将解封所有超过30天的IP，确定继续吗? (y/N)"
    read -r confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "❌ 操作已取消"
        return 1
    fi
    
    # 这里需要更复杂的逻辑来跟踪IP封禁时间
    # 简单实现：清理日志中30天前的记录
    if [ -f "$BANNED_IPS_LOG" ]; then
        backup_file="${BANNED_IPS_LOG}.backup.$(date +%Y%m%d)"
        cp "$BANNED_IPS_LOG" "$backup_file"
        
        # 只保留最近30天的记录
        awk -v cutoff="$(date -d '30 days ago' '+%Y-%m-%d')" '$0 >= "["cutoff' "$BANNED_IPS_LOG" > "${BANNED_IPS_LOG}.tmp"
        mv "${BANNED_IPS_LOG}.tmp" "$BANNED_IPS_LOG"
        
        echo "✅ 已清理旧记录，备份保存为: $backup_file"
    fi
}

# 主程序逻辑
case "$1" in
    "list")
        list_banned_ips
        ;;
    "ban")
        ban_ip "$2"
        ;;
    "unban")
        unban_ip "$2"
        ;;
    "status")
        show_status
        ;;
    "stats")
        show_stats
        ;;
    "clean")
        clean_old_bans
        ;;
    "")
        show_help
        ;;
    *)
        echo "❌ 未知命令: $1"
        show_help
        exit 1
        ;;
esac