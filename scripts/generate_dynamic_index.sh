#!/bin/bash

# 动态index.html生成器 - s.linapp.fun
# 基于HTML统计数据生成动态主页

STATS_FILE="/home/main/data/html_stats/html_stats_$(date +%Y%m%d_%H%M).json"
OUTPUT_DIR="/home/main/data"
OUTPUT_FILE="$OUTPUT_DIR/s_linapp_index.html"
BACKUP_DIR="/home/main/site/backup"

# 测试模式参数
TEST_MODE=false

# 参数解析
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --test-mode)
                TEST_MODE=true
                shift
                ;;
            --stats-file=*)
                STATS_FILE="${1#*=}"
                shift
                ;;
            --output-dir=*)
                OUTPUT_DIR="${1#*=}"
                OUTPUT_FILE="$OUTPUT_DIR/s_linapp_index.html"
                shift
                ;;
            *)
                echo "未知参数: $1"
                exit 1
                ;;
        esac
    done
}

# 查找最新的统计文件
find_latest_stats() {
    if [[ ! -f "$STATS_FILE" ]]; then
        # 查找最新的统计文件
        local stats_dir=$(dirname "$STATS_FILE")
        if [[ -d "$stats_dir" ]]; then
            local latest=$(ls -t "$stats_dir"/html_stats_*.json 2>/dev/null | head -1)
            if [[ -n "$latest" ]]; then
                STATS_FILE="$latest"
            fi
        fi
    fi
}

# 备份现有的index.html
backup_existing() {
    if [[ -f "$OUTPUT_FILE" && "$TEST_MODE" = false ]]; then
        mkdir -p "$BACKUP_DIR"
        cp "$OUTPUT_FILE" "$BACKUP_DIR/index_backup_$(date +%Y%m%d_%H%M).html"
    fi
}

# 生成CSS样式
generate_css() {
    cat << 'EOF'
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: #333;
            line-height: 1.6;
        }

        .header {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            padding: 1rem 0;
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            z-index: 100;
            box-shadow: 0 2px 20px rgba(0,0,0,0.1);
        }

        .header-content {
            max-width: 1200px;
            margin: 0 auto;
            padding: 0 1rem;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .logo {
            font-size: 1.8rem;
            font-weight: bold;
            background: linear-gradient(45deg, #667eea, #764ba2);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }

        .nav-buttons {
            display: flex;
            gap: 0.5rem;
        }

        .nav-btn {
            background: linear-gradient(45deg, #667eea, #764ba2);
            color: white;
            border: none;
            padding: 0.5rem 1rem;
            border-radius: 20px;
            cursor: pointer;
            font-size: 0.9rem;
            transition: transform 0.2s;
            text-decoration: none;
        }

        .nav-btn:hover {
            transform: translateY(-2px);
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 100px 1rem 2rem;
        }

        .hero {
            text-align: center;
            color: white;
            margin-bottom: 3rem;
        }

        .hero h1 {
            font-size: 3rem;
            margin-bottom: 0.5rem;
            font-weight: 700;
        }

        .hero p {
            font-size: 1.2rem;
            opacity: 0.9;
            margin-bottom: 2rem;
        }

        .section {
            margin-bottom: 3rem;
        }

        .section-title {
            color: white;
            font-size: 1.8rem;
            margin-bottom: 1.5rem;
            text-align: center;
        }

        .cards-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 1.5rem;
        }

        .file-card {
            background: rgba(255, 255, 255, 0.95);
            border-radius: 15px;
            padding: 1.5rem;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
            transition: all 0.3s ease;
            text-decoration: none;
            color: inherit;
            display: block;
        }

        .file-card:hover {
            transform: translateY(-10px);
            box-shadow: 0 20px 40px rgba(0,0,0,0.15);
        }

        .file-icon {
            width: 60px;
            height: 60px;
            border-radius: 15px;
            margin-bottom: 1rem;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 1.5rem;
            color: white;
        }

        .file-title {
            font-size: 1.3rem;
            font-weight: 600;
            margin-bottom: 0.5rem;
            color: #333;
        }

        .file-desc {
            color: #666;
            line-height: 1.5;
            margin-bottom: 1rem;
        }

        .file-meta {
            color: #999;
            font-size: 0.9rem;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .visit-count {
            background: linear-gradient(45deg, #667eea, #764ba2);
            color: white;
            padding: 0.2rem 0.5rem;
            border-radius: 10px;
            font-size: 0.8rem;
        }

        .category-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
        }

        .category-card {
            background: rgba(255, 255, 255, 0.9);
            border-radius: 10px;
            padding: 1rem;
            text-align: center;
            transition: transform 0.3s ease;
        }

        .category-card:hover {
            transform: translateY(-5px);
        }

        .category-name {
            font-weight: 600;
            margin-bottom: 0.5rem;
            color: #333;
        }

        .category-stats {
            color: #666;
            font-size: 0.9rem;
        }

        .footer {
            text-align: center;
            color: rgba(255, 255, 255, 0.8);
            padding: 2rem;
            font-size: 0.9rem;
        }

        @media (max-width: 768px) {
            .hero h1 {
                font-size: 2rem;
            }

            .hero p {
                font-size: 1rem;
            }

            .cards-grid {
                grid-template-columns: 1fr;
                gap: 1rem;
            }

            .file-card {
                padding: 1rem;
            }

            .container {
                padding: 80px 0.5rem 1rem;
            }

            .category-grid {
                grid-template-columns: repeat(2, 1fr);
            }
        }

        @media (max-width: 480px) {
            .header-content {
                flex-direction: column;
                gap: 1rem;
            }

            .logo {
                font-size: 1.5rem;
            }

            .nav-buttons {
                flex-direction: column;
                gap: 0.5rem;
                width: 100%;
            }

            .nav-btn {
                text-align: center;
                width: 100%;
            }

            .category-grid {
                grid-template-columns: 1fr;
            }
        }
EOF
}

# 获取文件图标
get_file_icon() {
    local file="$1"
    local category="$2"
    
    case "$file" in
        index.html|home.html) echo "🏠" ;;
        blog*) echo "📝" ;;
        stats*) echo "📊" ;;
        vote*) echo "🗳️" ;;
        *pdf*) echo "📄" ;;
        *adtech*|*adx*) echo "📱" ;;
        *management*) echo "⚙️" ;;
        *git*) echo "🔧" ;;
        *) 
            case "$category" in
                首页) echo "🏠" ;;
                博客) echo "📝" ;;
                专业工具) echo "🔧" ;;
                工具页面) echo "⚡" ;;
                *) echo "📋" ;;
            esac
            ;;
    esac
}

# 获取文件背景色
get_file_color() {
    local file="$1"
    
    case "$file" in
        index.html|home.html) echo "linear-gradient(45deg, #2196F3, #1976D2)" ;;
        blog*) echo "linear-gradient(45deg, #4CAF50, #45a049)" ;;
        stats*) echo "linear-gradient(45deg, #FF9800, #F57C00)" ;;
        vote*) echo "linear-gradient(45deg, #9C27B0, #7B1FA2)" ;;
        *pdf*) echo "linear-gradient(45deg, #4CAF50, #45a049)" ;;
        *adtech*|*adx*) echo "linear-gradient(45deg, #f44336, #d32f2f)" ;;
        *management*) echo "linear-gradient(45deg, #607D8B, #455A64)" ;;
        *) echo "linear-gradient(45deg, #667eea, #764ba2)" ;;
    esac
}

# 生成文件卡片
generate_file_card() {
    local file="$1"
    local title="$2" 
    local desc="$3"
    local visits="$4"
    local modified="$5"
    local category="$6"
    local card_class="$7"
    
    local icon=$(get_file_icon "$file" "$category")
    local color=$(get_file_color "$file")
    local url_path="https://s.linapp.fun/$file"
    
    # 为根目录文件处理URL
    [[ "$file" =~ ^[^/]+\.html$ ]] && url_path="https://s.linapp.fun/$file"
    
    cat << EOF
            <a href="$url_path" class="file-card $card_class">
                <div class="file-icon" style="background: $color;">$icon</div>
                <div class="file-title">$title</div>
                <div class="file-desc">$desc</div>
                <div class="file-meta">
                    <span>$modified</span>
                    <span class="visit-count">$visits 次访问</span>
                </div>
            </a>
EOF
}

# 生成主页HTML
generate_html() {
    if [[ ! -f "$STATS_FILE" ]]; then
        echo "统计文件不存在: $STATS_FILE" >&2
        return 1
    fi
    
    mkdir -p "$OUTPUT_DIR"
    
    # 从统计文件读取数据
    local stats_content=$(cat "$STATS_FILE")
    local total_files=$(echo "$stats_content" | python3 -c "import json,sys; print(json.load(sys.stdin).get('total_files', 0))")
    local total_visits=$(echo "$stats_content" | python3 -c "import json,sys; print(json.load(sys.stdin).get('total_visits', 0))")
    local timestamp=$(echo "$stats_content" | python3 -c "import json,sys; print(json.load(sys.stdin).get('timestamp', 'unknown'))")
    
    cat > "$OUTPUT_FILE" << EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>s.linapp.fun - 静态文件浏览</title>
    <style>
$(generate_css)
    </style>
</head>
<body>
    <header class="header">
        <div class="header-content">
            <div class="logo">s.linapp.fun</div>
            <div class="nav-buttons">
                <a href="https://linapp.fun" class="nav-btn">🏠 返回主站</a>
                <a href="/stats.html" class="nav-btn">📊 访问统计</a>
            </div>
        </div>
    </header>

    <div class="container">
        <div class="hero">
            <h1>静态文件浏览</h1>
            <p>发现并浏览存储桶中的HTML文件 · 共 $total_files 个文件 · 总访问量 $total_visits</p>
        </div>

        <div class="section">
            <h2 class="section-title">📅 最新文件</h2>
            <div class="cards-grid">
EOF

    # 生成最新文件卡片（排除index.html，显示6个）
    echo "$stats_content" | python3 -c "
import json, sys
data = json.load(sys.stdin)

recent_files = data.get('recent_files', [])
popular_files = data.get('most_popular', [])

# 创建访问次数查找字典
visit_counts = {}
for popular in popular_files:
    visit_counts[popular['file']] = popular.get('visits', 0)

# 过滤掉index.html并取前6个
count = 0
for file_info in recent_files:
    file = file_info['file']
    if file != 'index.html' and count < 6:  # 排除index.html，最多显示6个
        category = file_info.get('category', '未分类')
        modified = file_info.get('modified', 'unknown')
        size = file_info.get('size', 0)
        visits = visit_counts.get(file, 0)
        
        # 生成标题和描述
        if 'blog' in file:
            title = '博客 - ' + file.replace('.html', '').replace('/', ' / ')
            desc = '博客相关页面'
        elif 'stats' in file:
            title = '统计页面'
            desc = '访问统计和数据分析'
        elif 'management' in file:
            title = '管理工具 - ' + file.split('/')[-1].replace('.html', '')
            desc = '管理和配置工具'
        elif 'adtech' in file:
            title = '广告技术 - ' + file.split('/')[-1].replace('.html', '')
            desc = '广告技术相关页面'
        else:
            title = file.replace('.html', '').replace('/', ' / ').replace('_', ' ').title()
            desc = f'{category} · 文件大小: {size} bytes'
        
        print(f'{file}|{title}|{desc}|{visits}|{modified}|{category}')
        count += 1
" | while IFS='|' read -r file title desc visits modified category; do
        if [[ -n "$file" ]]; then
            generate_file_card "$file" "$title" "$desc" "$visits" "$modified" "$category" "recent-file-card" >> "$OUTPUT_FILE"
        fi
    done

    cat >> "$OUTPUT_FILE" << EOF
            </div>
        </div>

        <div class="section">
            <h2 class="section-title">📋 全部HTML文件</h2>
            <div class="cards-grid">
EOF

    # 生成所有HTML文件卡片（排除index.html和最新文件中已显示的，按创建时间从早到晚排序）
    echo "$stats_content" | python3 -c "
import json, sys
from datetime import datetime
data = json.load(sys.stdin)

all_files = data.get('all_files', [])
recent_files = data.get('recent_files', [])
popular_files = data.get('most_popular', [])

# 创建访问次数查找字典
visit_counts = {}
for popular in popular_files:
    visit_counts[popular['file']] = popular.get('visits', 0)

# 获取最新文件部分显示的文件列表（排除index.html，前6个）
recent_files_displayed = set()
count = 0
for file_info in recent_files:
    if file_info['file'] != 'index.html' and count < 6:
        recent_files_displayed.add(file_info['file'])
        count += 1

# 过滤和排序：排除index.html和已在最新文件中显示的，按创建时间从早到晚排序
filtered_files = []
for file_info in all_files:
    file = file_info['file']
    if file != 'index.html' and file not in recent_files_displayed:
        filtered_files.append(file_info)

# 按修改时间排序（从早到晚）
try:
    filtered_files.sort(key=lambda x: datetime.strptime(x['modified'], '%Y-%m-%d %H:%M'))
except:
    # 如果时间格式解析失败，按文件名排序
    filtered_files.sort(key=lambda x: x['file'])

for file_info in filtered_files:
    file = file_info['file']
    category = file_info.get('category', '未分类')
    modified = file_info.get('modified', 'unknown')
    size = file_info.get('size', 0)
    visits = visit_counts.get(file, 0)
    
    # 生成标题和描述
    if 'blog' in file:
        title = '博客 - ' + file.replace('.html', '').replace('/', ' / ')
        desc = '博客相关页面'
    elif 'stats' in file:
        title = '统计页面'
        desc = '访问统计和数据分析'
    elif 'management' in file:
        title = '管理工具 - ' + file.split('/')[-1].replace('.html', '')
        desc = '管理和配置工具'
    elif 'adtech' in file:
        title = '广告技术 - ' + file.split('/')[-1].replace('.html', '')
        desc = '广告技术相关页面'
    else:
        title = file.replace('.html', '').replace('/', ' / ').replace('_', ' ').title()
        desc = f'{category} · 文件大小: {size} bytes'
    
    print(f'{file}|{title}|{desc}|{visits}|{modified}|{category}')
" | while IFS='|' read -r file title desc visits modified category; do
        if [[ -n "$file" ]]; then
            generate_file_card "$file" "$title" "$desc" "$visits" "$modified" "$category" "all-file-card" >> "$OUTPUT_FILE"
        fi
    done

    cat >> "$OUTPUT_FILE" << EOF
            </div>
        </div>
    </div>

    <footer class="footer">
        <p>&copy; 2025 s.linapp.fun · 静态文件浏览器 · 最后更新: $timestamp</p>
    </footer>

</body>
</html>
EOF
}

# 主函数
main() {
    parse_args "$@"
    find_latest_stats
    backup_existing
    
    echo "开始生成动态index.html..."
    echo "统计文件: $STATS_FILE"
    echo "输出文件: $OUTPUT_FILE"
    
    if ! generate_html; then
        echo "生成失败" >&2
        exit 1
    fi
    
    echo "生成完成: $OUTPUT_FILE"
    if [[ "$TEST_MODE" = true ]]; then
        echo "测试模式运行完成"
    fi
}

# 运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi