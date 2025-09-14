#!/bin/bash

# 攻击IP分析脚本 - 分析过去24小时访问日志，分类显示威胁IP和正常IP
# 威胁IP显示5个（已封禁的IP），正常IP显示10个（未封禁的IP）

ATTACK_LOG="/home/main/logs/attack_analysis_24h.json"
NGINX_LOG="/var/log/nginx/access.log"
BANNED_IPS_LOG="/home/main/logs/banned_ips.log"
SECURITY_LOG="/home/main/logs/realtime_security.log"

# 获取过去24小时的时间范围
get_time_range() {
    local start_time=$(date -d '24 hours ago' '+%d/%b/%Y:%H:%M')
    local end_time=$(date '+%d/%b/%Y:%H:%M')
    echo "$start_time|$end_time"
}

# 使用GeoIP工具获取IP地理位置信息
get_ip_location() {
    local ip="$1"
    
    # 检查是否为内网IP
    if [[ $ip =~ ^10\. ]] || [[ $ip =~ ^192\.168\. ]] || [[ $ip =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] || [[ $ip =~ ^127\. ]]; then
        echo "内网IP"
        return
    fi
    
    # 使用geoiplookup查询地理位置
    local geo_result=$(timeout 3 geoiplookup "$ip" 2>/dev/null)
    if [[ -n "$geo_result" ]] && [[ "$geo_result" != *"can't resolve hostname"* ]]; then
        # 提取国家和地区信息
        if [[ "$geo_result" =~ GeoIP\ Country\ Edition:\ ([^,]+),\ (.+)$ ]]; then
            local country_code="${BASH_REMATCH[1]}"
            local country_name="${BASH_REMATCH[2]}"
            echo "${country_code}-${country_name}"
        else
            echo "$geo_result" | sed 's/GeoIP Country Edition: //' | head -1
        fi
    else
        # 备用方法：使用简单的IP段识别
        local first_octet=$(echo "$ip" | cut -d'.' -f1)
        case "$first_octet" in
            1|2|3|4|5|6|7|8|9|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31)
                echo "US-北美地区"
                ;;
            51|52|54|99|100)
                echo "US-云服务提供商"
                ;;
            157|159|164|167)
                echo "US-数据中心"
                ;;
            91|92|94)
                echo "欧洲"
                ;;
            152)
                echo "AU-亚太地区"
                ;;
            *)
                echo "位置未知"
                ;;
        esac
    fi
}

# 分析访问日志，获取前15个访问最多的IP
analyze_top_ips() {
    local time_range=$(get_time_range)
    local start_time=$(echo "$time_range" | cut -d'|' -f1)
    local end_time=$(echo "$time_range" | cut -d'|' -f2)
    
    # 从nginx日志中提取过去24小时的IP访问统计
    {
        cat "$NGINX_LOG" 2>/dev/null
        [[ -f "/var/log/nginx/access.log.1" ]] && cat "/var/log/nginx/access.log.1" 2>/dev/null
        
        # 也检查二级域名的日志
        for domain_log in /var/log/nginx/*.access.log; do
            [[ -f "$domain_log" ]] && cat "$domain_log" 2>/dev/null | head -1000
        done
        
    } | awk '
    BEGIN {
        # AWK脚本开始
    }
    {
        # 提取IP和时间
        ip = $1
        if (match($0, /\[([^\]]+)\]/, time_match)) {
            timestamp = time_match[1]
            # 统计所有IP访问
            ip_count[ip]++
            
            # 记录请求详情用于攻击模式分析
            if (match($0, /"([^"]*)"/, request_match)) {
                request = request_match[1]
                # 限制每个IP记录的请求样本数量
                if (split(ip_requests[ip], existing_requests, "@@") < 10) {
                    ip_requests[ip] = ip_requests[ip] request "@@"
                }
            }
            
            # 提取域名信息
            domain = "linapp.fun"  # 默认主域名
            
            # 检查是否有域名标记（来自域名专用日志）
            if (match($0, /###DOMAIN:([^###]+)$/, domain_mark)) {
                domain = domain_mark[1]
                # 移除域名标记，恢复原始日志行
                gsub(/###DOMAIN:[^###]+$/, "", $0)
            }
            # 否则从主日志使用默认域名
            # 不再尝试从referrer提取域名，因为大多数情况下referrer为空
            
            # 统计每个IP访问的域名频次
            key = ip "###" domain
            ip_hosts[key]++
        }
    }
    END {
        # 按访问次数排序，输出前25个IP（确保有足够IP分类）
        PROCINFO["sorted_in"] = "@val_num_desc"
        count = 0
        for (ip in ip_count) {
            if (count >= 25) break
            
            # 构建该IP的top3访问域名
            top_hosts = ""
            host_count = 0
            # 收集当前IP的所有域名及访问次数
            delete hosts_array
            for (key in ip_hosts) {
                if (index(key, ip "###") == 1) {
                    host = substr(key, length(ip "###") + 1)
                    visits = ip_hosts[key]
                    hosts_array[host] = visits
                }
            }
            
            # 按访问次数排序取前3个
            PROCINFO["sorted_in"] = "@val_num_desc"
            for (host in hosts_array) {
                if (host_count >= 3) break
                if (top_hosts != "") top_hosts = top_hosts "@@"
                top_hosts = top_hosts host ":" hosts_array[host]
                host_count++
            }
            
            printf "%s|%d|%s|%s\n", ip, ip_count[ip], ip_requests[ip], top_hosts
            count++
        }
    }'
}

# 检测IP的威胁等级和攻击模式
analyze_ip_threat() {
    local ip="$1"
    local requests="$2"
    local attack_score=0
    local attack_reasons=()
    local security_notes=()
    
    # 检查是否已被封禁
    local banned_status="未封禁"
    # 优先检查iptables实际封禁状态（更精确的匹配）
    if sudo iptables -L INPUT -n 2>/dev/null | grep -E "DROP.*--.*${ip}[[:space:]]" >/dev/null; then
        banned_status="已封禁"
        security_notes+=("🚫 已被封禁")
    elif [[ -f "$BANNED_IPS_LOG" ]] && grep -q "$ip" "$BANNED_IPS_LOG"; then
        banned_status="已封禁"
        security_notes+=("🚫 已被封禁")
    fi
    
    # 分析攻击模式
    if echo "$requests" | grep -q "\.env"; then
        attack_score=$((attack_score + 2))
        attack_reasons+=("敏感配置文件扫描(.env)")
    fi
    
    if echo "$requests" | grep -q "wp-admin\|wp-login\|wp-config\|wordpress"; then
        attack_score=$((attack_score + 1))
        attack_reasons+=("WordPress漏洞扫描")
    fi
    
    if echo "$requests" | grep -q "phpinfo\|php-fpm\|eval-stdin\.php\|test\.php"; then
        attack_score=$((attack_score + 1))
        attack_reasons+=("PHP配置文件扫描")
    fi
    
    if echo "$requests" | grep -q "admin\|login\|dashboard\|management"; then
        attack_score=$((attack_score + 1))
        attack_reasons+=("管理后台扫描")
    fi
    
    if echo "$requests" | grep -q "allow_url_include\|php://input\|base64_decode"; then
        attack_score=$((attack_score + 2))
        attack_reasons+=("代码注入尝试")
    fi
    
    if echo "$requests" | grep -q "\.\./\|\.\.%2f\|%2e%2e"; then
        attack_score=$((attack_score + 2))
        attack_reasons+=("目录遍历攻击")
    fi
    
    if echo "$requests" | grep -q "mysql\|database\|sql\|phpmyadmin"; then
        attack_score=$((attack_score + 1))
        attack_reasons+=("数据库系统扫描")
    fi
    
    if echo "$requests" | grep -q "\.git/\|\.svn/\|\.hg/"; then
        attack_score=$((attack_score + 1))
        attack_reasons+=("版本控制系统扫描")
    fi
    
    if echo "$requests" | grep -q "backup\|\.bak\|\.old\|\.sql\|\.zip\|\.tar"; then
        attack_score=$((attack_score + 1))
        attack_reasons+=("备份文件扫描")
    fi
    
    # 根据访问次数判断
    local request_count=$(echo "$requests" | tr '@@' '\n' | wc -l)
    if [[ $request_count -gt 100 ]]; then
        security_notes+=("🔥 高频访问")
    fi
    
    # 确定威胁等级
    local threat_level="正常"
    if [[ $attack_score -ge 5 ]]; then
        threat_level="高危"
        security_notes+=("🚨 需要立即处理")
    elif [[ $attack_score -ge 2 ]]; then
        threat_level="可疑"
        security_notes+=("⚠️ 建议关注")
    fi
    
    # 输出结果格式：threat_level|attack_score|attack_reasons|banned_status|security_notes
    local attack_reasons_json="[]"
    if [[ ${#attack_reasons[@]} -gt 0 ]]; then
        attack_reasons_json=$(printf '%s\n' "${attack_reasons[@]}" | jq -R . | jq -s -c .)
    fi
    
    local security_notes_json="[]"
    if [[ ${#security_notes[@]} -gt 0 ]]; then
        security_notes_json=$(printf '%s\n' "${security_notes[@]}" | jq -R . | jq -s -c .)
    fi
    
    # 确保输出格式正确，避免换行符影响
    echo "${threat_level}|${attack_score}|${attack_reasons_json}|${banned_status}|${security_notes_json}"
}

# 主程序
main() {
    echo "开始分析过去24小时的IP访问情况..." >&2
    
    # 统计关键数字
    echo "正在统计关键安全指标..." >&2
    
    # 1. 统计总共被封禁的IP数量
    local total_banned_ips=$(sudo iptables -L INPUT -n 2>/dev/null | grep "DROP" | grep -E "^DROP.*--.*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | wc -l)
    
    # 2. 统计过去24小时访问的不同IP总数
    local unique_ips_24h=$(analyze_top_ips | wc -l)
    
    # 3. 统计总计访问的不同IP数（所有时段）- 分析更长时间的日志
    local total_unique_ips=$(
        {
            cat "$NGINX_LOG" 2>/dev/null
            [[ -f "/var/log/nginx/access.log.1" ]] && cat "/var/log/nginx/access.log.1" 2>/dev/null
            for domain_log in /var/log/nginx/*.access.log*; do
                [[ -f "$domain_log" ]] && zcat -f "$domain_log" 2>/dev/null | head -10000
            done
        } | awk '{print $1}' | sort -u | wc -l
    )
    
    echo "📊 关键安全统计：" >&2
    echo "   - 总计访问的不同IP数（所有时段）: $total_unique_ips 个" >&2
    echo "   - 总共被封禁的IP数量: $total_banned_ips 个" >&2
    echo "   - 过去24小时访问的不同IP数: $unique_ips_24h 个" >&2
    
    # 存储关键统计信息供后续使用
    key_stats_total_banned=$total_banned_ips
    key_stats_unique_24h=$unique_ips_24h
    key_stats_total_unique=$total_unique_ips
    
    # 分析顶级IP
    local top_ips_data=$(analyze_top_ips)
    
    # 获取当前所有被封禁的IP，确保它们也被分析
    local banned_ips_list=$(sudo iptables -L INPUT -n 2>/dev/null | grep "DROP" | grep -E "^DROP.*--.*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | awk '{print $4}')
    
    echo "正在整合被封禁IP到分析列表..." >&2
    
    # 为被封禁的IP创建基本记录（如果它们不在访问日志中）
    for banned_ip in $banned_ips_list; do
        if ! echo "$top_ips_data" | grep -q "^$banned_ip|"; then
            # 这个被封禁的IP不在24小时访问记录中，添加基本记录
            top_ips_data="$top_ips_data"$'\n'"$banned_ip|0|威胁IP（已封禁）|"
        fi
    done
    
    # 初始化数组
    threat_ips=()
    normal_ips=()
    all_ips=()
    
    # 分析每个IP的威胁情况
    while IFS='|' read -r ip count requests top_hosts; do
        [[ -z "$ip" ]] && continue
        
        # 获取地理位置
        local location=$(get_ip_location "$ip")
        
        # 分析威胁等级
        local threat_analysis=$(analyze_ip_threat "$ip" "$requests")
        IFS='|' read -r threat_level attack_score attack_reasons banned_status security_notes <<< "$threat_analysis"
        
        # 处理请求样本（取前3个）- 确保JSON格式正确并移除换行符
        local sample_requests="[]"
        if [[ -n "$requests" ]]; then
            sample_requests=$(echo "$requests" | tr '@@' '\n' | head -3 | jq -R . | jq -s -c . 2>/dev/null || echo "[]")
        fi
        
        # 处理top3访问网站信息 - 移除换行符
        local top_sites="[]"
        if [[ -n "$top_hosts" ]]; then
            top_sites=$(echo "$top_hosts" | tr '@@' '\n' | while read -r site_info; do
                if [[ -n "$site_info" ]]; then
                    IFS=':' read -r domain visits <<< "$site_info"
                    echo "{\"domain\":\"$domain\",\"visits\":$visits}"
                fi
            done | jq -s -c . 2>/dev/null || echo "[]")
        fi
        
        # 构建简化的IP对象
        local ip_object=$(cat <<EOF
{
  "ip": "$ip",
  "request_count": $count,
  "banned_status": "$banned_status",
  "threat_level": "$threat_level",
  "attack_score": $attack_score,
  "location": "$location",
  "visit_details": "$count 次访问"
}
EOF
)
        
        # 验证JSON格式
        if ! echo "$ip_object" | jq . >/dev/null 2>&1; then
            echo "警告: IP对象JSON格式错误，跳过 $ip" >&2
            continue
        fi
        
        # 临时存储IP基本信息，使用###作为分隔符避免冲突
        all_ips+=("$ip###$count###$attack_score###$banned_status###$threat_level###$attack_reasons###$location###$security_notes###$sample_requests###$top_sites")
        
    done <<< "$top_ips_data"
    
    # 按攻击评分和封禁状态重新分类
    # 使用自定义排序函数处理多字符分隔符
    local sorted_ips=()
    local temp_file=$(mktemp)
    
    # 将IP数据写入临时文件，添加索引用于排序
    local index=0
    for ip_data in "${all_ips[@]}"; do
        local fields
        IFS='###' read -ra fields <<< "$ip_data"
        local attack_score="${fields[2]:-0}"
        echo "$attack_score###$index###$ip_data" >> "$temp_file"
        ((index++))
    done
    
    # 按攻击评分排序（数字排序，从高到低）
    while IFS= read -r line; do
        # 从排序后的行中提取原始ip_data
        # 格式：score###index###ip_data，我们需要跳过前两个字段
        local ip_data=$(echo "$line" | sed 's/^[^#]*###[^#]*###//')
        sorted_ips+=("$ip_data")
    done < <(sort -t'#' -k1 -nr "$temp_file")
    
    rm -f "$temp_file"
    
    # 重新分类并重新构建IP对象
    for ip_data in "${sorted_ips[@]}"; do
        # 使用bash字符串操作解析多字符分隔符
        local temp="$ip_data"
        local ip="${temp%%###*}"; temp="${temp#*###}"
        local count="${temp%%###*}"; temp="${temp#*###}"
        local attack_score="${temp%%###*}"; temp="${temp#*###}"
        local banned_status="${temp%%###*}"; temp="${temp#*###}"
        local threat_level="${temp%%###*}"; temp="${temp#*###}"
        local attack_reasons="${temp%%###*}"; temp="${temp#*###}"
        local location="${temp%%###*}"; temp="${temp#*###}"
        local security_notes="${temp%%###*}"; temp="${temp#*###}"
        local sample_requests="${temp%%###*}"; temp="${temp#*###}"
        local top_sites="${temp}"
        
        # 重新构建简化的IP对象
        local ip_object=$(cat <<EOF
{
  "ip": "$ip",
  "request_count": $count,
  "banned_status": "$banned_status",
  "threat_level": "$threat_level",
  "attack_score": $attack_score,
  "location": "$location",
  "visit_details": "$count 次访问"
}
EOF
)
        
        # 威胁IP：已封禁的 + 高危未封禁的（攻击评分>=5）
        if [[ "$banned_status" == "已封禁" ]] || [[ $attack_score -ge 5 ]]; then
            if [[ ${#threat_ips[@]} -lt 5 ]]; then
                threat_ips+=("$ip_object")
            fi
        # 正常IP：低风险未封禁的
        elif [[ "$banned_status" != "已封禁" && $attack_score -lt 5 ]]; then
            if [[ ${#normal_ips[@]} -lt 10 ]]; then
                normal_ips+=("$ip_object")
            fi
        fi
    done
    
    # 构建JSON输出
    echo "正在生成分析报告..." >&2
    
    # 转换数组为JSON
    local threat_ips_json="[]"
    if [[ ${#threat_ips[@]} -gt 0 ]]; then
        threat_ips_json=$(printf '%s\n' "${threat_ips[@]}" | jq -s . 2>/dev/null || echo "[]")
    fi
    
    local normal_ips_json="[]"
    if [[ ${#normal_ips[@]} -gt 0 ]]; then
        normal_ips_json=$(printf '%s\n' "${normal_ips[@]}" | jq -s . 2>/dev/null || echo "[]")
    fi
    
    # 统计所有IP的威胁情况（不只是显示的IP）
    local all_threat_count=0
    local all_normal_count=0
    local banned_in_24h_count=0
    
    for ip_data in "${sorted_ips[@]}"; do
        # 使用bash字符串操作解析多字符分隔符
        local temp="$ip_data"
        local ip="${temp%%###*}"; temp="${temp#*###}"
        local count="${temp%%###*}"; temp="${temp#*###}"
        local attack_score="${temp%%###*}"; temp="${temp#*###}"
        local banned_status="${temp%%###*}"; temp="${temp#*###}"
        if [[ "$banned_status" == "已封禁" ]] || [[ $attack_score -ge 5 ]]; then
            ((all_threat_count++))
            # 统计过去24小时有威胁并封禁的IP
            if [[ "$banned_status" == "已封禁" ]]; then
                ((banned_in_24h_count++))
            fi
        else
            ((all_normal_count++))
        fi
    done
    
    # 显示统计
    local display_threat_count=${#threat_ips[@]}
    local display_normal_count=${#normal_ips[@]}
    local total_unique_ips=$((display_threat_count + display_normal_count))
    
    echo "   - 过去24小时有威胁并封禁的IP数: $banned_in_24h_count 个" >&2
    echo "" >&2
    echo "过去24小时IP统计：威胁IP共 $all_threat_count 个，正常IP共 $all_normal_count 个" >&2
    echo "本次显示：威胁IP前 $display_threat_count 个，正常IP前 $display_normal_count 个" >&2
    
    # 生成最终JSON
    cat > "$ATTACK_LOG" <<EOF
{
  "threat_ips": $threat_ips_json,
  "normal_ips": $normal_ips_json,
  "attack_summary": {
    "total_unique_ips": $total_unique_ips,
    "threat_count": $display_threat_count,
    "normal_count": $display_normal_count,
    "all_threat_count": $all_threat_count,
    "all_normal_count": $all_normal_count,
    "total_analyzed_ips": $((all_threat_count + all_normal_count)),
    "last_update": "$(date '+%Y-%m-%d %H:%M')",
    "analysis_period": "过去24小时"
  },
  "key_security_stats": {
    "total_unique_ips": $key_stats_total_unique,
    "total_banned_ips": $key_stats_total_banned,
    "banned_in_24h": $banned_in_24h_count,
    "unique_ips_24h": $key_stats_unique_24h,
    "ban_rate": "$(echo "scale=1; $banned_in_24h_count * 100 / $key_stats_unique_24h" | bc 2>/dev/null || echo "0")%",
    "total_ban_rate": "$(echo "scale=1; $key_stats_total_banned * 100 / $key_stats_total_unique" | bc 2>/dev/null || echo "0")%"
  }
}
EOF
    
    echo "IP威胁分析完成：显示威胁IP ${display_threat_count}个，正常IP ${display_normal_count}个" >&2
    echo "分析结果已保存到：$ATTACK_LOG" >&2
}

# 执行主程序
main "$@"