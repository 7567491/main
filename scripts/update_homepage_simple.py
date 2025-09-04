#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
主页卡片动态更新脚本
功能：根据top7排行榜数据动态更新主页的7个项目卡片
执行频率：每小时执行一次
"""

import json
import re
import os
import shutil
from datetime import datetime

# 配置文件路径
WEBCLICK_DIR = "/mnt/www/webclick"
INDEX_FILE = "/mnt/www/index.html"
BACKUP_DIR = "/home/main/site/backup"
DOMAINS_CONFIG = "/home/main/data/domains_config.json"



def load_domains_config():
    """加载域名配置文件"""
    if not os.path.exists(DOMAINS_CONFIG):
        raise FileNotFoundError(f"未找到域名配置文件: {DOMAINS_CONFIG}")
    
    with open(DOMAINS_CONFIG, 'r', encoding='utf-8') as f:
        config = json.load(f)
    
    return config

def load_top7_data():
    """加载最新的top7排行数据"""
    top7_file = os.path.join(WEBCLICK_DIR, "latest_top7.json")
    
    if not os.path.exists(top7_file):
        raise FileNotFoundError(f"未找到排行数据文件: {top7_file}")
    
    with open(top7_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    return data

def generate_card_html(item, domains_config):
    """生成单个项目卡片的HTML"""
    # 获取项目信息
    short_name = item['short_name']
    domain = item['domain']
    url = item['url']
    visits_7d = item['visits_7d']
    
    # 从配置文件获取域名信息
    domain_config = domains_config['domains'].get(domain)
    if domain_config:
        title = domain_config['title']
        description = domain_config['description']
        icon = domain_config['icon']
        color = domain_config['color']
    else:
        # 默认值
        title = item['display_name']
        description = "专业工具平台，提供高效的在线服务"
        icon = "🔧"
        color = "linear-gradient(45deg, #607D8B, #455A64)"
    
    # 生成HTML
    card_html = f'''            <a href="{url}" class="project-card">
                <div class="project-icon" style="background: {color};">{icon}</div>
                <div class="project-title">{title}</div>
                <div class="project-desc">{description}</div>
                <div class="project-url">{domain}</div>
                <div class="visit-count" style="font-size: 0.8rem; color: #999; margin-top: 0.5rem;">📊 过去7天: {visits_7d:,} 次访问</div>
            </a>'''
    
    return card_html

def update_homepage(top7_data, domains_config):
    """更新主页HTML文件"""
    timestamp = datetime.now().strftime('%Y%m%d_%H%M')
    
    # 检查主页文件是否存在
    if not os.path.exists(INDEX_FILE):
        raise FileNotFoundError(f"未找到主页文件: {INDEX_FILE}")
    
    # 创建备份
    os.makedirs(BACKUP_DIR, exist_ok=True)
    backup_file = os.path.join(BACKUP_DIR, f"index_backup_{timestamp}.html")
    shutil.copy2(INDEX_FILE, backup_file)
    print(f"已创建备份: {backup_file}")
    
    # 读取当前主页内容
    with open(INDEX_FILE, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 验证内容完整性
    if len(content) < 1000:  # 主页文件应该比较大
        raise ValueError("主页文件内容异常，可能已损坏")
    
    # 检查是否存在重复内容（基础检测）
    projects_grid_count = content.count('<div class="projects-grid">')
    if projects_grid_count != 1:
        print(f"警告: 发现 {projects_grid_count} 个 projects-grid，可能存在重复内容")
        if projects_grid_count > 1:
            print("检测到重复内容，将使用清理模式")
    
    # 生成新的卡片HTML
    cards_html = []
    for item in top7_data['top7']:
        card = generate_card_html(item, domains_config)
        cards_html.append(card)
    
    new_cards_section = "\n\n".join(cards_html)
    
    # 使用更精确的标记替换项目卡片部分
    # 找到 projects-grid 开始和结束的位置
    grid_start = '<div class="projects-grid">'
    grid_start_pos = content.find(grid_start)
    
    if grid_start_pos == -1:
        print("错误: 未找到 projects-grid 开始标记")
        return False
    
    # 从 grid_start_pos 开始寻找匹配的结束标记
    search_pos = grid_start_pos + len(grid_start)
    div_count = 1  # 已经有一个开始的div
    grid_end_pos = -1
    
    while search_pos < len(content) and div_count > 0:
        next_div_open = content.find('<div', search_pos)
        next_div_close = content.find('</div>', search_pos)
        
        if next_div_close == -1:
            break
            
        if next_div_open != -1 and next_div_open < next_div_close:
            div_count += 1
            search_pos = next_div_open + 4
        else:
            div_count -= 1
            if div_count == 0:
                grid_end_pos = next_div_close + 6  # 包含 </div>
                break
            search_pos = next_div_close + 6
    
    if grid_end_pos == -1:
        print("错误: 未找到匹配的 projects-grid 结束标记")
        return False
    
    # 构建新内容
    new_content = (
        content[:grid_start_pos + len(grid_start)] + 
        f'\n{new_cards_section}\n        ' +
        content[grid_end_pos:]
    )
    
    if new_content == content:
        print("警告: 未找到可替换的项目卡片部分")
        return False
    
    # 保存更新后的内容
    with open(INDEX_FILE, 'w', encoding='utf-8') as f:
        f.write(new_content)
    
    print("主页HTML更新成功!")
    return True

def sync_to_s3():
    """同步到S3存储桶（如果配置了s3cmd）"""
    if shutil.which('s3cmd'):
        print("同步主页到存储桶...")
        os.system(f"s3cmd put {INDEX_FILE} s3://www/index.html --acl-public")
        print("同步完成")
    else:
        print("未找到s3cmd，跳过存储桶同步")

def main():
    """主函数"""
    print(f"开始更新主页卡片 - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    try:
        # 加载配置和排行数据
        domains_config = load_domains_config()
        data = load_top7_data()
        print(f"数据更新时间: {data['last_update']}")
        print("Top7排行:")
        
        for item in data['top7']:
            rank = item['rank']
            display_name = item['display_name']
            domain = item['domain']
            visits_7d = item['visits_7d']
            print(f"  {rank}. {display_name} - {visits_7d:,} 次访问 ({domain})")
        
        print()
        
        # 更新主页
        if update_homepage(data, domains_config):
            print("✅ 主页卡片更新成功！")
            
            # 同步到存储桶
            sync_to_s3()
            
        else:
            print("❌ 主页更新失败")
            return 1
            
    except Exception as e:
        print(f"❌ 更新过程中出错: {e}")
        return 1
    
    print(f"更新完成 - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("---")
    return 0

if __name__ == "__main__":
    exit(main())