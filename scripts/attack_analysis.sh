#!/bin/bash

# 攻击IP分析脚本 - 分析过去24小时访问日志，分类显示威胁IP和正常IP
# 威胁IP显示5个，正常IP显示10个

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
                if (split(ip_requests[ip], existing_requests, "|||") < 10) {
                    ip_requests[ip] = ip_requests[ip] request "|||"
                }
            }
        }
    }
    END {
        # 按访问次数排序，输出前15个IP
        PROCINFO["sorted_in"] = "@val_num_desc"
        count = 0
        for (ip in ip_count) {
            if (count >= 15) break
            printf "%s|%d|%s\n", ip, ip_count[ip], ip_requests[ip]
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
    local banned_status="未知"
    if [[ -f "$BANNED_IPS_LOG" ]] && grep -q "$ip" "$BANNED_IPS_LOG"; then
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
    local request_count=$(echo "$requests" | tr '|||' '\n' | wc -l)
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
        attack_reasons_json=$(printf '%s\n' "${attack_reasons[@]}" | jq -R . | jq -s . | tr -d '\n')
    fi
    
    local security_notes_json="[]"
    if [[ ${#security_notes[@]} -gt 0 ]]; then
        security_notes_json=$(printf '%s\n' "${security_notes[@]}" | jq -R . | jq -s . | tr -d '\n')
    fi
    
    # 确保输出格式正确，避免换行符影响
    echo "${threat_level}|${attack_score}|${attack_reasons_json}|${banned_status}|${security_notes_json}"
}

# 主程序
main() {
    echo "开始分析过去24小时的IP访问情况..." >&2
    
    # 分析顶级IP
    local top_ips_data=$(analyze_top_ips)
    
    # 初始化数组
    threat_ips=()
    normal_ips=()
    
    # 分析每个IP的威胁情况
    while IFS='|' read -r ip count requests; do
        [[ -z "$ip" ]] && continue
        
        # 获取地理位置
        local location=$(get_ip_location "$ip")
        
        # 分析威胁等级
        local threat_analysis=$(analyze_ip_threat "$ip" "$requests")
        IFS='|' read -r threat_level attack_score attack_reasons banned_status security_notes <<< "$threat_analysis"
        
        # 处理请求样本（取前3个）- 确保JSON格式正确
        local sample_requests="[]"
        if [[ -n "$requests" ]]; then
            sample_requests=$(echo "$requests" | tr '|||' '\n' | head -3 | jq -R . | jq -s . 2>/dev/null || echo "[]")
        fi
        
        # 构建IP对象 - 使用简单的字符串拼接方法
        local ip_object=$(cat <<EOF
{
  "ip": "$ip",
  "request_count": $count,
  "banned_status": "$banned_status",
  "threat_level": "$threat_level",
  "attack_score": $attack_score,
  "attack_reasons": $attack_reasons,
  "location": "$location",
  "security_notes": $security_notes,
  "sample_requests": $sample_requests
}
EOF
)
        
        # 验证JSON格式
        if ! echo "$ip_object" | jq . >/dev/null 2>&1; then
            echo "警告: IP对象JSON格式错误，跳过 $ip" >&2
            continue
        fi
        
        # 根据威胁等级分类
        if [[ "$threat_level" == "高危" || "$threat_level" == "可疑" ]]; then
            if [[ ${#threat_ips[@]} -lt 5 ]]; then
                threat_ips+=("$ip_object")
            fi
        else
            if [[ ${#normal_ips[@]} -lt 10 ]]; then
                normal_ips+=("$ip_object")
            fi
        fi
        
    done <<< "$top_ips_data"
    
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
    
    # 统计信息
    local total_threat_count=${#threat_ips[@]}
    local total_normal_count=${#normal_ips[@]}
    local total_unique_ips=$((total_threat_count + total_normal_count))
    
    # 生成最终JSON
    cat > "$ATTACK_LOG" <<EOF
{
  "threat_ips": $threat_ips_json,
  "normal_ips": $normal_ips_json,
  "attack_summary": {
    "total_unique_ips": $total_unique_ips,
    "threat_count": $total_threat_count,
    "normal_count": $total_normal_count,
    "last_update": "$(date '+%Y-%m-%d %H:%M')",
    "analysis_period": "过去24小时"
  }
}
EOF
    
    echo "IP威胁分析完成：威胁IP ${total_threat_count}个，正常IP ${total_normal_count}个" >&2
    echo "分析结果已保存到：$ATTACK_LOG" >&2
}

# 执行主程序
main "$@"