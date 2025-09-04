#!/bin/bash

# 主页卡片动态更新脚本
# 功能：根据top6排行榜数据动态更新主页的6个项目卡片
# 执行频率：每小时执行一次（在统计脚本之后）

WEBCLICK_DIR="/mnt/www/webclick"
INDEX_FILE="/mnt/www/index.html"
BACKUP_DIR="/home/main/site/backup"
TIMESTAMP=$(date '+%Y%m%d_%H%M')

echo "开始更新主页卡片 - $(date)"

# 检查数据文件是否存在
if [[ ! -f "$WEBCLICK_DIR/latest_top6.json" ]]; then
    echo "错误: 未找到最新的top6数据文件"
    exit 1
fi

# 检查主页文件是否存在
if [[ ! -f "$INDEX_FILE" ]]; then
    echo "错误: 未找到主页文件 $INDEX_FILE"
    exit 1
fi

# 创建备份
mkdir -p "$BACKUP_DIR"
cp "$INDEX_FILE" "$BACKUP_DIR/index_backup_${TIMESTAMP}.html"
echo "已创建备份: $BACKUP_DIR/index_backup_${TIMESTAMP}.html"

# 读取top6数据并提取信息
echo "读取最新排行数据..."

# 使用python解析JSON更可靠
python3 << 'EOF'
import json
import sys
import os

try:
    # 读取top6数据
    with open('/mnt/www/webclick/latest_top6.json', 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    top6 = data['top6']
    last_update = data['last_update']
    
    print(f"数据更新时间: {last_update}")
    print("Top6排行:")
    
    # 生成卡片数据
    cards = []
    
    for i, item in enumerate(top6):
        rank = item['rank']
        display_name = item['display_name']
        domain = item['domain']
        url = item['url']
        visits_7d = item['visits_7d']
        
        # 提取图标和名称
        parts = display_name.split(' ', 1)
        if len(parts) == 2:
            icon = parts[0]
            name = parts[1]
        else:
            icon = "🔧"
            name = display_name
            
        # 生成描述（基于域名类型）
        short_name = item['short_name']
        if short_name == 'app':
            desc = "智能PR、FAQ、文档生成工具，支持多种内容创作需求"
        elif short_name == 'az':
            desc = "地图统计、区域分析、数据可视化工具"
        elif short_name == 'didi':
            desc = "客户信息管理、数据处理、业务分析系统"
        elif short_name == 'pdf':
            desc = "PDF文档处理、转换、编辑工具"
        elif short_name == 'vote':
            desc = "在线投票、问卷调查、数据收集平台"
        elif short_name == 'meet':
            desc = "在线会议、协作工具、团队沟通平台"
        elif short_name == '6page':
            desc = "快速网页生成、模板设计、内容发布工具"
        elif short_name == 'dianbo':
            desc = "在线点播、媒体播放、内容分发平台"
        else:
            desc = "专业工具平台，提供高效的在线服务"
        
        # 确定颜色主题（循环使用6种颜色）
        colors = [
            "linear-gradient(45deg, #4CAF50, #45a049)",  # 绿色
            "linear-gradient(45deg, #2196F3, #1976D2)",  # 蓝色
            "linear-gradient(45deg, #FF9800, #F57C00)",  # 橙色
            "linear-gradient(45deg, #f44336, #d32f2f)",  # 红色
            "linear-gradient(45deg, #9C27B0, #7B1FA2)",  # 紫色
            "linear-gradient(45deg, #607D8B, #455A64)"   # 灰蓝色
        ]
        color = colors[i % len(colors)]
        
        card = {
            'rank': rank,
            'icon': icon,
            'name': name,
            'desc': desc,
            'url': url,
            'domain_text': domain,
            'visits_7d': visits_7d,
            'color': color
        }
        cards.append(card)
        
        print(f"  {rank}. {display_name} - {visits_7d} 次访问 ({domain})")
    
    # 输出卡片数据供bash脚本使用
    print("CARDS_JSON_START")
    print(json.dumps(cards, ensure_ascii=False, indent=2))
    print("CARDS_JSON_END")
    
except Exception as e:
    print(f"处理JSON数据时出错: {e}", file=sys.stderr)
    sys.exit(1)
EOF

# 捕获Python输出
PYTHON_OUTPUT=$(python3 << 'EOF'
import json
import sys

try:
    with open('/mnt/www/webclick/latest_top6.json', 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    cards = []
    colors = [
        "linear-gradient(45deg, #4CAF50, #45a049)",
        "linear-gradient(45deg, #2196F3, #1976D2)",
        "linear-gradient(45deg, #FF9800, #F57C00)",
        "linear-gradient(45deg, #f44336, #d32f2f)",
        "linear-gradient(45deg, #9C27B0, #7B1FA2)",
        "linear-gradient(45deg, #607D8B, #455A64)"
    ]
    
    for i, item in enumerate(data['top6']):
        parts = item['display_name'].split(' ', 1)
        icon = parts[0] if len(parts) == 2 else "🔧"
        name = parts[1] if len(parts) == 2 else item['display_name']
        
        short_name = item['short_name']
        desc_map = {
            'app': "智能PR、FAQ、文档生成工具，支持多种内容创作需求",
            'az': "地图统计、区域分析、数据可视化工具", 
            'didi': "客户信息管理、数据处理、业务分析系统",
            'pdf': "PDF文档处理、转换、编辑工具",
            'vote': "在线投票、问卷调查、数据收集平台",
            'meet': "在线会议、协作工具、团队沟通平台",
            '6page': "快速网页生成、模板设计、内容发布工具",
            'dianbo': "在线点播、媒体播放、内容分发平台"
        }
        desc = desc_map.get(short_name, "专业工具平台，提供高效的在线服务")
        
        card = f"{item['rank']}|{icon}|{name}|{desc}|{item['url']}|{item['domain']}|{item['visits_7d']}|{colors[i % len(colors)]}"
        cards.append(card)
    
    for card in cards:
        print(card)
        
except Exception as e:
    sys.exit(1)
EOF
)

if [[ $? -ne 0 ]]; then
    echo "解析JSON数据失败"
    exit 1
fi

echo ""
echo "生成新的项目卡片HTML..."

# 生成新的项目卡片HTML
NEW_CARDS_HTML=""
while IFS='|' read -r rank icon name desc url domain visits color; do
    # 添加访问量显示的HTML
    visit_display="<div class=\"visit-count\" style=\"font-size: 0.8rem; color: #999; margin-top: 0.5rem;\">📊 过去7天: ${visits} 次访问</div>"
    
    card_html="            <a href=\"$url\" class=\"project-card\">
                <div class=\"project-icon\" style=\"background: $color;\">$icon</div>
                <div class=\"project-title\">$name</div>
                <div class=\"project-desc\">$desc</div>
                <div class=\"project-url\">$domain</div>
                <div class=\"visit-count\" style=\"font-size: 0.8rem; color: #999; margin-top: 0.5rem;\">📊 过去7天: $visits 次访问</div>
            </a>"
    
    if [[ -n "$NEW_CARDS_HTML" ]]; then
        NEW_CARDS_HTML="$NEW_CARDS_HTML

$card_html"
    else
        NEW_CARDS_HTML="$card_html"
    fi
done <<< "$PYTHON_OUTPUT"

# 创建临时文件进行替换
TEMP_FILE="/tmp/index_update_$$.html"
cp "$INDEX_FILE" "$TEMP_FILE"

# 使用awk替换项目卡片部分
awk '
BEGIN { in_cards = 0; cards_printed = 0 }
/<div class="projects-grid">/ { print; in_cards = 1; next }
/<\/div>/ && in_cards { 
    if (!cards_printed) {
        print "'"${NEW_CARDS_HTML}"'"
        cards_printed = 1
    }
    print; in_cards = 0; next 
}
in_cards { next }
{ print }
' "$TEMP_FILE" > "${TEMP_FILE}_new"

# 检查新文件是否生成成功
if [[ -s "${TEMP_FILE}_new" ]]; then
    mv "${TEMP_FILE}_new" "$INDEX_FILE"
    echo "主页更新成功!"
    echo "已根据最新排行更新6个项目卡片"
else
    echo "更新失败，保留原文件"
    rm -f "$TEMP_FILE" "${TEMP_FILE}_new"
    exit 1
fi

# 清理临时文件
rm -f "$TEMP_FILE"

# 同步到存储桶（如果需要）
if command -v s3cmd >/dev/null 2>&1; then
    echo "同步主页到存储桶..."
    s3cmd put "$INDEX_FILE" s3://www/index.html --acl-public
    echo "同步完成"
fi

echo "主页卡片更新完成 - $(date)"
echo "---"