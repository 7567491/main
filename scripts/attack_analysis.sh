#!/bin/bash

# 攻击IP分析脚本 - 分析过去24小时访问日志，统计前5个IP和封禁情况

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

# 分析访问日志，获取前5个访问最多的IP
analyze_top_ips() {
    local time_range=$(get_time_range)
    local start_time=$(echo "$time_range" | cut -d'|' -f1)
    local end_time=$(echo "$time_range" | cut -d'|' -f2)
    
    # 从nginx日志中提取过去24小时的IP访问统计
    {
        cat "$NGINX_LOG" 2>/dev/null
        [[ -f "/var/log/nginx/access.log.1" ]] && cat "/var/log/nginx/access.log.1" 2>/dev/null
    } | awk -v start_time="$start_time" -v end_time="$end_time" '
    BEGIN {
        # 将时间转换为可比较的格式
        split(start_time, start_parts, "[/:]")
        split(end_time, end_parts, "[/:]")
    }
    {
        # 提取IP和时间
        ip = $1
        if (match($0, /\[([^\]]+)\]/, time_match)) {
            timestamp = time_match[1]
            # 简单的时间过滤 - 提取所有记录用于统计
            ip_count[ip]++
            
            # 记录请求详情用于攻击模式分析
            if (match($0, /"([^"]*)"/, request_match)) {
                request = request_match[1]
                ip_requests[ip] = ip_requests[ip] request "|||"
            }
        }
    }
    END {
        # 按访问次数排序，输出前10个IP
        PROCINFO["sorted_in"] = "@val_num_desc"
        count = 0
        for (ip in ip_count) {
            if (++count <= 10) {
                print ip ":" ip_count[ip] ":" ip_requests[ip]
            }
        }
    }
    '
}

# 检查IP是否被封禁
check_banned_status() {
    local ip="$1"
    # 检查iptables规则
    if sudo iptables -L INPUT -n 2>/dev/null | grep -q "$ip"; then
        echo "已封禁"
        return
    fi
    # 检查封禁日志
    if [[ -f "$BANNED_IPS_LOG" ]] && grep -q "$ip" "$BANNED_IPS_LOG" 2>/dev/null; then
        echo "已封禁"
        return
    fi
    # 检查实时安全监控日志
    if [[ -f "$SECURITY_LOG" ]] && grep -q "成功封禁IP: $ip" "$SECURITY_LOG" 2>/dev/null; then
        echo "已封禁"
        return
    fi
    # 检查最近的安全监控活动（过去1小时）
    if [[ -f "$SECURITY_LOG" ]]; then
        local recent_ban=$(grep "成功封禁IP: $ip" "$SECURITY_LOG" | tail -1)
        if [[ -n "$recent_ban" ]]; then
            echo "已封禁"
            return
        fi
    fi
    echo "正常"
}

# 分析攻击模式并生成详细描述
analyze_attack_patterns_detailed() {
    local requests="$1"
    local attack_reasons=()
    
    # 敏感文件扫描检测
    if echo "$requests" | grep -qi "\.env"; then
        attack_reasons+=("敏感配置文件扫描(.env)")
    fi
    
    # WordPress相关扫描
    if echo "$requests" | grep -qi "wp-admin\|wp-login\|wordpress\|wp-"; then
        attack_reasons+=("WordPress漏洞扫描")
    fi
    
    # 配置文件扫描
    if echo "$requests" | grep -qi "config\.php\|phpinfo\|admin\.php"; then
        attack_reasons+=("PHP配置文件扫描")
    fi
    
    # 目录遍历攻击
    if echo "$requests" | grep -qi "\.\.\/\|%2e%2e"; then
        attack_reasons+=("目录遍历攻击")
    fi
    
    # 代码注入尝试
    if echo "$requests" | grep -qi "eval\|base64\|php://input\|allow_url_include"; then
        attack_reasons+=("代码注入尝试")
    fi
    
    # 管理后台扫描
    if echo "$requests" | grep -qi "/admin\|/login\|/dashboard"; then
        attack_reasons+=("管理后台扫描")
    fi
    
    # 数据库相关
    if echo "$requests" | grep -qi "phpmyadmin\|mysql\|database"; then
        attack_reasons+=("数据库系统扫描")
    fi
    
    # Git相关敏感目录
    if echo "$requests" | grep -qi "\.git\/\|\.svn\/"; then
        attack_reasons+=("版本控制系统扫描")
    fi
    
    # 备份文件扫描
    if echo "$requests" | grep -qi "\.bak\|\.backup\|\.sql"; then
        attack_reasons+=("备份文件扫描")
    fi
    
    # 返回攻击原因列表（用|分隔）
    if [ ${#attack_reasons[@]} -gt 0 ]; then
        printf '%s|' "${attack_reasons[@]}" | sed 's/|$//'
    else
        echo ""
    fi
}

# 获取地理位置信息 (增强版)
get_location_info() {
    local ip="$1"
    # 内网IP判断
    case "$ip" in
        10.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[0-1].*) echo "内网IP" ; return ;;
        127.*) echo "本地回环" ; return ;;
    esac
    
    # 尝试使用whois获取详细信息
    if command -v whois >/dev/null 2>&1; then
        local whois_result=$(timeout 8 whois "$ip" 2>/dev/null)
        
        # 提取国家信息（支持多种格式）
        local country=$(echo "$whois_result" | grep -i -E "^country:|country:" | head -1 | awk -F: '{print $2}' | tr -d ' ' | tr '[:lower:]' '[:upper:]')
        
        # 提取组织信息
        local org=$(echo "$whois_result" | grep -i -E "^org(name)?:|organization:" | head -1 | awk -F: '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
        
        # 提取网络名称
        local netname=$(echo "$whois_result" | grep -i "netname:" | head -1 | awk -F: '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
        
        # 根据获取到的信息构建位置描述
        if [[ -n "$country" && -n "$org" ]]; then
            # 缩短组织名称
            local short_org=$(echo "$org" | sed 's/,.*//' | cut -c1-15)
            echo "$country-$short_org"
        elif [[ -n "$country" ]]; then
            echo "$country(未知ISP)"
        elif [[ -n "$org" ]]; then
            local short_org=$(echo "$org" | sed 's/,.*//' | cut -c1-20)
            echo "外网-$short_org"
        elif [[ -n "$netname" ]]; then
            local short_net=$(echo "$netname" | cut -c1-20)
            echo "外网-$short_net"
        else
            # 通过IP段判断大致地理位置（回退方案）
            local first_octet=$(echo "$ip" | cut -d'.' -f1)
            case "$first_octet" in
                91) echo "欧洲(未知ISP)" ;;
                37) echo "欧洲(未知ISP)" ;;
                108) echo "US-Cloudflare" ;;
                162) echo "US-Cloudflare" ;;
                13) echo "US-AWS" ;;
                152) echo "APNIC地区" ;;
                157) echo "US-DigitalOcean" ;;
                44) echo "US-AWS" ;;
                198) echo "美国(未知ISP)" ;;
                *) echo "外网(未识别)" ;;
            esac
        fi
    else
        # whois不可用时的回退方案
        echo "无whois工具"
    fi
}

echo "开始分析攻击IP和封禁状态..."

# 获取前5个IP的详细信息
top_ips_data=$(analyze_top_ips)

# 使用Python生成JSON数据
python3 << PYTHON_EOF
import json
from datetime import datetime

# 解析Shell脚本的输出
top_ips_raw = """$top_ips_data"""

attack_data = {
    "top_ips": [],
    "attack_summary": {
        "total_unique_ips": 0,
        "banned_count": 0,
        "suspicious_count": 0,
        "normal_count": 0,
        "last_update": datetime.now().strftime("%Y-%m-%d %H:%M"),
        "analysis_period": "过去24小时"
    }
}

# 处理每个IP的数据
for line in top_ips_raw.strip().split('\n'):
    if not line:
        continue
    
    parts = line.split(':', 2)
    if len(parts) >= 2:
        ip = parts[0].strip()
        count = int(parts[1])
        requests = parts[2] if len(parts) > 2 else ""
        
        # 检查封禁状态
        import subprocess
        try:
            # 调用bash函数检查封禁状态
            check_cmd = f"source /home/main/scripts/attack_analysis.sh && check_banned_status '{ip}'"
            result = subprocess.run(['bash', '-c', check_cmd], capture_output=True, text=True, timeout=5)
            banned_status = result.stdout.strip() if result.returncode == 0 else "未知"
        except:
            banned_status = "未知"
        
        # 直接在Python中获取地理位置信息（更可靠）
        def get_ip_location(ip_addr):
            # 内网IP判断
            if ip_addr.startswith(('10.', '192.168.', '172.')) or '127.' in ip_addr:
                return "内网IP"
            
            try:
                # 使用whois获取详细信息
                whois_result = subprocess.run(['timeout', '5', 'whois', ip_addr], 
                                            capture_output=True, text=True, timeout=8)
                if whois_result.returncode == 0:
                    whois_output = whois_result.stdout
                    
                    # 提取国家信息
                    country_lines = [line for line in whois_output.split('\n') 
                                   if 'country:' in line.lower()]
                    country = ""
                    if country_lines:
                        country = country_lines[0].split(':')[-1].strip().upper()
                    
                    # 提取组织信息
                    org_lines = [line for line in whois_output.split('\n') 
                               if any(key in line.lower() for key in ['orgname:', 'organization:', 'org:'])]
                    org = ""
                    if org_lines:
                        org = org_lines[0].split(':', 1)[-1].strip()
                        org = org[:20]  # 截断长组织名
                    
                    # 构建位置描述
                    if country and org:
                        return f"{country}-{org}"
                    elif country:
                        return f"{country}(未知ISP)"
                    elif org:
                        return f"外网-{org}"
                    else:
                        # 基于IP段的回退判断
                        first_octet = int(ip_addr.split('.')[0])
                        ip_mapping = {
                            91: "欧洲", 37: "欧洲", 108: "US-Cloudflare", 162: "US-Cloudflare",
                            13: "US-AWS", 152: "APNIC地区", 157: "US-DigitalOcean", 
                            44: "US-AWS", 198: "美国"
                        }
                        return ip_mapping.get(first_octet, "外网(未识别)")
                else:
                    return "查询失败"
            except:
                return "查询超时"
        
        location = get_ip_location(ip)
        
        # 直接在Python中分析攻击模式（更高效）
        attack_reasons = []
        requests_lower = requests.lower()
        
        if ".env" in requests_lower:
            attack_reasons.append("敏感配置文件扫描(.env)")
        if any(wp in requests_lower for wp in ["wp-admin", "wp-login", "wordpress", "wp-"]):
            attack_reasons.append("WordPress漏洞扫描")
        if any(cfg in requests_lower for cfg in ["config.php", "phpinfo", "admin.php"]):
            attack_reasons.append("PHP配置文件扫描")
        if any(trav in requests_lower for trav in ["../", "%2e%2e"]):
            attack_reasons.append("目录遍历攻击")
        if any(inj in requests_lower for inj in ["eval", "base64", "php://input", "allow_url_include"]):
            attack_reasons.append("代码注入尝试")
        if any(admin in requests_lower for admin in ["/admin", "/login", "/dashboard"]):
            attack_reasons.append("管理后台扫描")
        if any(db in requests_lower for db in ["phpmyadmin", "mysql", "database"]):
            attack_reasons.append("数据库系统扫描")
        if any(git in requests_lower for git in [".git/", ".svn/"]):
            attack_reasons.append("版本控制系统扫描")
        if any(bak in requests_lower for bak in [".bak", ".backup", ".sql"]):
            attack_reasons.append("备份文件扫描")
        
        # 计算攻击分数和判断威胁级别
        attack_score = len(attack_reasons)
        if attack_score >= 3:
            threat_level = "高危"
            attack_data["attack_summary"]["suspicious_count"] += 1
        elif attack_score >= 1:
            threat_level = "可疑"  
            attack_data["attack_summary"]["suspicious_count"] += 1
        else:
            threat_level = "正常"
            attack_data["attack_summary"]["normal_count"] += 1
        
        # 如果是高危或可疑IP，添加额外的安全信息
        security_notes = []
        if threat_level in ["高危", "可疑"]:
            if banned_status == "已封禁":
                security_notes.append("✅ 已自动封禁")
            else:
                security_notes.append("⚠️ 建议关注")
                if attack_score >= 3:
                    security_notes.append("🚨 需要立即处理")
        
        # 高频访问检测
        if count > 200:
            security_notes.append("🔥 高频访问")
            if threat_level == "正常":
                threat_level = "可疑"
        
        ip_info = {
            "ip": ip,
            "request_count": count,
            "banned_status": banned_status,
            "threat_level": threat_level,
            "attack_score": attack_score,
            "attack_reasons": attack_reasons,
            "location": location,
            "security_notes": security_notes,
            "sample_requests": [req for req in requests.split('|||')[:3] if req.strip()]  # 取前3个非空请求作为样本
        }
        
        attack_data["top_ips"].append(ip_info)
        
        if banned_status == "已封禁":
            attack_data["attack_summary"]["banned_count"] += 1

# 更新总计数据
attack_data["attack_summary"]["total_unique_ips"] = len(attack_data["top_ips"])

# 写入JSON文件
with open("$ATTACK_LOG", 'w') as f:
    json.dump(attack_data, f, indent=2, ensure_ascii=False)

print(f"攻击分析完成，分析了{len(attack_data['top_ips'])}个IP")
print(f"发现{attack_data['attack_summary']['suspicious_count']}个可疑IP")
print(f"已封禁{attack_data['attack_summary']['banned_count']}个IP")
PYTHON_EOF

echo "攻击IP分析完成: $(date)"
