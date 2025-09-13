#!/bin/bash

# HTML文件访问统计脚本 - s.linapp.fun专用
# 分析nginx日志，生成HTML文件访问统计

LOG_FILE="/var/log/nginx/s.linapp.fun.access.log"
SCAN_DIR="/mnt/www"
OUTPUT_DIR="/home/main/data/html_stats"
TIMESTAMP=$(date +"%Y%m%d_%H%M")
OUTPUT_FILE="$OUTPUT_DIR/html_stats_$TIMESTAMP.json"

# 测试模式参数
TEST_MODE=false
TEMP_DIR="/tmp/html_stats_$$"

# 参数解析
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --test-mode)
                TEST_MODE=true
                shift
                ;;
            --log-file=*)
                LOG_FILE="${1#*=}"
                shift
                ;;
            --output-dir=*)
                OUTPUT_DIR="${1#*=}"
                shift
                ;;
            --scan-dir=*)
                SCAN_DIR="${1#*=}"
                shift
                ;;
            *)
                echo "未知参数: $1"
                exit 1
                ;;
        esac
    done
    
    # 更新输出文件路径
    OUTPUT_FILE="$OUTPUT_DIR/html_stats_$TIMESTAMP.json"
}

# 创建必要目录
setup_directories() {
    mkdir -p "$OUTPUT_DIR" 2>/dev/null || true
    mkdir -p "$TEMP_DIR" 2>/dev/null || true
}

# 扫描HTML文件
scan_html_files() {
    if [[ ! -d "$SCAN_DIR" ]]; then
        echo "扫描目录不存在: $SCAN_DIR" >&2
        return 1
    fi
    
    find "$SCAN_DIR" -name "*.html" -type f -printf '%T@ %p\n' 2>/dev/null | \
    sort -nr | while read timestamp filepath; do
        # 计算相对路径
        relative_path=${filepath#$SCAN_DIR/}
        [[ "$relative_path" == "$filepath" ]] && relative_path=${filepath#$SCAN_DIR}
        [[ "$relative_path" =~ ^/ ]] && relative_path=${relative_path#/}
        
        # 获取文件信息
        file_size=$(stat -c%s "$filepath" 2>/dev/null || echo "0")
        last_modified=$(date -d "@$timestamp" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")
        
        echo "$relative_path|$file_size|$last_modified"
    done > "$TEMP_DIR/html_files.txt"
}

# 分析访问日志
analyze_access_logs() {
    if [[ ! -f "$LOG_FILE" ]]; then
        echo "日志文件不存在: $LOG_FILE" >&2
        return 1
    fi
    
    # 提取HTML文件访问记录（过去7天）
    local start_date=$(date -d "7 days ago" "+%d/%b/%Y")
    
    awk -v start_date="$start_date" '
    BEGIN {
        # 月份映射
        months["Jan"] = 1; months["Feb"] = 2; months["Mar"] = 3; months["Apr"] = 4
        months["May"] = 5; months["Jun"] = 6; months["Jul"] = 7; months["Aug"] = 8
        months["Sep"] = 9; months["Oct"] = 10; months["Nov"] = 11; months["Dec"] = 12
    }
    {
        # 提取请求URL和时间
        if (match($0, /"GET ([^"]*\.html[^"]*) HTTP/, url_match) && 
            match($4, /\[([0-9]{2})\/([A-Za-z]{3})\/([0-9]{4}):/, date_match)) {
            
            url = url_match[1]
            day = date_match[1]
            month = months[date_match[2]]
            year = date_match[3]
            
            # 清理URL，移除查询参数和开头斜杠
            gsub(/\?.*/, "", url)
            gsub(/^\//, "", url)
            
            # 简单的日期过滤（只统计最近的访问）
            visits[url]++
            last_visit[url] = day "/" date_match[2] "/" year
        }
    }
    END {
        for (url in visits) {
            printf "%s|%d|%s\n", url, visits[url], (last_visit[url] ? last_visit[url] : "unknown")
        }
    }' "$LOG_FILE" | sort -t'|' -k2 -nr > "$TEMP_DIR/access_stats.txt"
}

# 文件分类
categorize_files() {
    local file="$1"
    
    if [[ "$file" =~ ^(index|home)\.html$ ]]; then
        echo "首页"
    elif [[ "$file" =~ ^blog/ ]]; then
        echo "博客"
    elif [[ "$file" =~ ^(adtech|management|tech-blog|ai-projects)/ ]]; then
        echo "专业工具"
    elif [[ "$file" =~ ^others/ ]]; then
        echo "其他项目"
    elif [[ "$file" =~ ^(stats|vote|git|mig)\.html$ ]]; then
        echo "工具页面"
    elif [[ "$file" =~ \/ ]]; then
        echo "子目录"
    else
        echo "根目录"
    fi
}

# 生成JSON统计报告
generate_json_report() {
    local total_files=0
    local total_visits=0
    
    echo '{' > "$OUTPUT_FILE"
    echo '"timestamp":"'"$TIMESTAMP"'",' >> "$OUTPUT_FILE"
    echo '"scan_directory":"'"$SCAN_DIR"'",' >> "$OUTPUT_FILE"
    echo '"log_file":"'"$LOG_FILE"'",' >> "$OUTPUT_FILE"
    
    # 统计总数
    if [[ -f "$TEMP_DIR/html_files.txt" ]]; then
        total_files=$(wc -l < "$TEMP_DIR/html_files.txt")
    fi
    
    if [[ -f "$TEMP_DIR/access_stats.txt" ]]; then
        total_visits=$(awk -F'|' '{sum += $2} END {print sum}' "$TEMP_DIR/access_stats.txt")
    fi
    
    echo '"total_files":'$total_files',' >> "$OUTPUT_FILE"
    echo '"total_visits":'${total_visits:-0}',' >> "$OUTPUT_FILE"
    
    # 最近文件（按修改时间排序）
    echo '"recent_files":[' >> "$OUTPUT_FILE"
    if [[ -f "$TEMP_DIR/html_files.txt" ]]; then
        head -10 "$TEMP_DIR/html_files.txt" | while IFS='|' read -r file size modified; do
            local category=$(categorize_files "$file")
            
            # 检查是否是最后一行
            local line_count=$(head -10 "$TEMP_DIR/html_files.txt" | wc -l)
            local current_line=$(head -10 "$TEMP_DIR/html_files.txt" | grep -n "^$file" | head -1 | cut -d: -f1)
            
            echo -n '{"file":"'"$file"'","size":'$size',"modified":"'"$modified"'","category":"'"$category"'"}' >> "$OUTPUT_FILE"
            if [[ $current_line -ne $line_count ]]; then
                echo ',' >> "$OUTPUT_FILE"
            else
                echo '' >> "$OUTPUT_FILE"
            fi
        done
    fi
    echo '],' >> "$OUTPUT_FILE"
    
    # 所有HTML文件列表
    echo '"all_files":[' >> "$OUTPUT_FILE"
    if [[ -f "$TEMP_DIR/html_files.txt" ]]; then
        while IFS='|' read -r file size modified; do
            local category=$(categorize_files "$file")
            
            # 检查是否是最后一行
            local line_count=$(wc -l < "$TEMP_DIR/html_files.txt")
            local current_line=$(grep -n "^$file" "$TEMP_DIR/html_files.txt" | head -1 | cut -d: -f1)
            
            echo -n '{"file":"'"$file"'","size":'$size',"modified":"'"$modified"'","category":"'"$category"'"}' >> "$OUTPUT_FILE"
            if [[ $current_line -ne $line_count ]]; then
                echo ',' >> "$OUTPUT_FILE"
            else
                echo '' >> "$OUTPUT_FILE"
            fi
        done < "$TEMP_DIR/html_files.txt"
    fi
    echo '],' >> "$OUTPUT_FILE"
    
    # 访问最多的文件
    echo '"most_popular":[' >> "$OUTPUT_FILE"
    if [[ -f "$TEMP_DIR/access_stats.txt" ]]; then
        head -10 "$TEMP_DIR/access_stats.txt" | while IFS='|' read -r file visits last_visit; do
            local category=$(categorize_files "$file")
            
            # 检查是否是最后一行
            local line_count=$(head -10 "$TEMP_DIR/access_stats.txt" | wc -l)
            local current_line=$(head -10 "$TEMP_DIR/access_stats.txt" | grep -n "^$file" | head -1 | cut -d: -f1)
            
            echo -n '{"file":"'"$file"'","visits":'$visits',"last_visit":"'"$last_visit"'","category":"'"$category"'"}' >> "$OUTPUT_FILE"
            if [[ $current_line -ne $line_count ]]; then
                echo ',' >> "$OUTPUT_FILE"
            else
                echo '' >> "$OUTPUT_FILE"
            fi
        done
    fi
    echo '],' >> "$OUTPUT_FILE"
    
    # 分类统计
    echo '"categories":{' >> "$OUTPUT_FILE"
    
    declare -A category_stats
    declare -A category_visits
    
    # 统计每个分类的文件数量
    if [[ -f "$TEMP_DIR/html_files.txt" ]]; then
        while IFS='|' read -r file size modified; do
            local category=$(categorize_files "$file")
            category_stats["$category"]=$((${category_stats["$category"]:-0} + 1))
        done < "$TEMP_DIR/html_files.txt"
    fi
    
    # 统计每个分类的访问量
    if [[ -f "$TEMP_DIR/access_stats.txt" ]]; then
        while IFS='|' read -r file visits last_visit; do
            local category=$(categorize_files "$file")
            category_visits["$category"]=$((${category_visits["$category"]:-0} + visits))
        done < "$TEMP_DIR/access_stats.txt"
    fi
    
    # 输出分类统计
    local first=true
    for category in "${!category_stats[@]}"; do
        [[ "$first" = true ]] && first=false || echo ',' >> "$OUTPUT_FILE"
        echo -n '"'"$category"'":{"files":'${category_stats[$category]}',"visits":'${category_visits[$category]:-0}'}' >> "$OUTPUT_FILE"
    done
    echo '' >> "$OUTPUT_FILE"
    
    echo '}' >> "$OUTPUT_FILE"
    echo '}' >> "$OUTPUT_FILE"
}

# 清理临时文件
cleanup() {
    rm -rf "$TEMP_DIR" 2>/dev/null || true
}

# 主函数
main() {
    parse_args "$@"
    setup_directories
    
    echo "开始HTML文件访问统计..."
    echo "扫描目录: $SCAN_DIR"
    echo "日志文件: $LOG_FILE"
    echo "输出文件: $OUTPUT_FILE"
    
    # 扫描HTML文件
    if ! scan_html_files; then
        echo "HTML文件扫描失败" >&2
        cleanup
        exit 1
    fi
    
    # 分析访问日志
    if ! analyze_access_logs; then
        echo "访问日志分析失败" >&2
        cleanup
        exit 1
    fi
    
    # 生成报告
    if ! generate_json_report; then
        echo "JSON报告生成失败" >&2
        cleanup
        exit 1
    fi
    
    cleanup
    
    echo "统计完成: $OUTPUT_FILE"
    if [[ "$TEST_MODE" = true ]]; then
        echo "测试模式运行完成"
    fi
}

# 运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi