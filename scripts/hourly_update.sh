#!/bin/bash

# 每小时自动更新脚本
# 功能：统计域名访问量排行 → 更新主页卡片 → 同步数据
# 执行频率：每小时执行一次（整点）

SCRIPT_DIR="/home/main/scripts"
LOG_DIR="/home/main/logs"
TIMESTAMP=$(date '+%Y%m%d_%H%M')

# 创建日志目录
mkdir -p "$LOG_DIR"

# 日志文件
HOURLY_LOG="$LOG_DIR/hourly_update.log"

echo "=====================================" >> "$HOURLY_LOG"
echo "开始每小时自动更新 - $(date)" >> "$HOURLY_LOG"
echo "=====================================" >> "$HOURLY_LOG"

# 1. 执行域名访问量统计
echo "步骤1: 统计域名访问量排行" >> "$HOURLY_LOG"
if "$SCRIPT_DIR/domain_stats_ranking.sh" >> "$HOURLY_LOG" 2>&1; then
    echo "✅ 域名统计完成" >> "$HOURLY_LOG"
else
    echo "❌ 域名统计失败" >> "$HOURLY_LOG"
    exit 1
fi

# 等待2秒确保文件已生成
sleep 2

# 2. 更新主页卡片  
echo "步骤2: 更新主页卡片" >> "$HOURLY_LOG"
if python3 "$SCRIPT_DIR/update_homepage_simple.py" >> "$HOURLY_LOG" 2>&1; then
    echo "✅ 主页更新完成" >> "$HOURLY_LOG"
else
    echo "❌ 主页更新失败" >> "$HOURLY_LOG"
    exit 1
fi

# 3. 记录完成状态
echo "✅ 每小时自动更新完成 - $(date)" >> "$HOURLY_LOG"
echo "" >> "$HOURLY_LOG"

# 保留最近30天的日志
find "$LOG_DIR" -name "hourly_update.log" -mtime +30 -delete 2>/dev/null || true

echo "自动更新完成"