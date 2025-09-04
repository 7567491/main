#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
技术博客文章搜集脚本
搜集/mnt/www目录中的技术博客相关HTML文件，生成blog_data.json
"""

import os
import re
import json
import time
from datetime import datetime
from pathlib import Path
from html.parser import HTMLParser
import logging

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/home/main/logs/blog_collector.log'),
        logging.StreamHandler()
    ]
)

class HTMLTitleParser(HTMLParser):
    """HTML标题提取器"""
    def __init__(self):
        super().__init__()
        self.title = ""
        self.in_title = False
        self.meta_description = ""
        
    def handle_starttag(self, tag, attrs):
        if tag == "title":
            self.in_title = True
        elif tag == "meta":
            attrs_dict = dict(attrs)
            if attrs_dict.get("name") == "description":
                self.meta_description = attrs_dict.get("content", "")
    
    def handle_endtag(self, tag):
        if tag == "title":
            self.in_title = False
    
    def handle_data(self, data):
        if self.in_title:
            self.title += data

class BlogCollector:
    """博客文章搜集器"""
    
    def __init__(self):
        self.www_dir = Path("/mnt/www")
        self.output_file = Path("/home/main/logs/blog_data.json")
        self.excluded_files = {
            'index.html', 'stats.html', 'blog.html', 'manifest.json', 
            'sw.js', 'api.php', 'all.html', 'vote.html', 'meet.html'
        }
        self.excluded_dirs = {'log', 'webclick', 'pic'}
        
        # 技术分类关键词 - 重组为四个主要分类
        self.categories = {
            'AI技术': ['ai', 'claude', 'tts', 'voice', 'machine-learning', 'ai-projects'],
            '架构设计': ['architecture', 'system', 'design', 'tech-blog', 'ssl', 'qcp'],
            '广告技术': ['adtech', 'dsp', 'adx', 'rtb', 'sx'],
            '管理技术': ['management', 'paper', 'pdf', 'meituan', 'product', 'streamlit', 'prfaq', 'git', 'lincon', 'mig', 'others']
        }
    
    def extract_content_from_html(self, file_path):
        """从HTML文件提取标题和描述"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            parser = HTMLTitleParser()
            parser.feed(content)
            
            title = parser.title.strip() if parser.title else ""
            description = parser.meta_description.strip()
            
            # 如果没有meta描述，尝试提取第一段文本
            if not description:
                # 移除HTML标签，获取纯文本
                text = re.sub(r'<[^>]+>', ' ', content)
                text = re.sub(r'\s+', ' ', text).strip()
                
                # 提取前200个字符作为描述
                if len(text) > 200:
                    description = text[:200] + "..."
                else:
                    description = text if text else "技术文章内容详细介绍..."
            
            return title, description
            
        except Exception as e:
            logging.error(f"解析文件 {file_path} 时出错: {e}")
            return "", ""
    
    def determine_category(self, file_path):
        """根据文件路径和名称确定分类"""
        path_str = str(file_path).lower()
        filename = file_path.name.lower()
        
        for category, keywords in self.categories.items():
            for keyword in keywords:
                if keyword in path_str or keyword in filename:
                    return category
        
        return "技术文章"
    
    def get_file_date(self, file_path):
        """获取文件修改时间"""
        try:
            timestamp = os.path.getmtime(file_path)
            return datetime.fromtimestamp(timestamp).strftime('%Y-%m-%d')
        except:
            return datetime.now().strftime('%Y-%m-%d')
    
    def is_tech_blog_file(self, file_path):
        """判断是否为技术博客文件"""
        filename = file_path.name.lower()
        parent_dir = file_path.parent.name.lower()
        
        # 排除特定文件
        if filename in self.excluded_files:
            return False
        
        # 排除特定目录
        if parent_dir in self.excluded_dirs:
            return False
        
        # 只处理HTML文件
        if not filename.endswith('.html'):
            return False
        
        # 排除以下模式的文件
        exclude_patterns = [
            r'zhanglu.*\.html',  # 个人展示页面
            r'.*showcase.*\.html'  # 展示页面
        ]
        
        for pattern in exclude_patterns:
            if re.match(pattern, filename):
                return False
        
        return True
    
    def collect_blog_files(self):
        """搜集所有技术博客文件"""
        blog_articles = []
        
        try:
            for file_path in self.www_dir.rglob("*.html"):
                if not self.is_tech_blog_file(file_path):
                    continue
                
                logging.info(f"处理文件: {file_path}")
                
                # 提取文章信息
                title, description = self.extract_content_from_html(file_path)
                category = self.determine_category(file_path)
                date = self.get_file_date(file_path)
                
                # 生成相对URL
                relative_path = file_path.relative_to(self.www_dir)
                url = f"/{relative_path}"
                
                article = {
                    "title": title or file_path.stem.replace('-', ' ').title(),
                    "description": description,
                    "category": category,
                    "date": date,
                    "url": url,
                    "file_path": str(file_path)
                }
                
                blog_articles.append(article)
        
        except Exception as e:
            logging.error(f"搜集博客文件时出错: {e}")
        
        return blog_articles
    
    def generate_blog_data(self):
        """生成博客数据JSON文件"""
        logging.info("开始搜集技术博客文章...")
        
        articles = self.collect_blog_files()
        
        # 按日期排序（最新的在前）
        articles.sort(key=lambda x: x['date'], reverse=True)
        
        blog_data = {
            "lastUpdate": datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            "totalArticles": len(articles),
            "articles": articles,
            "categories": list(set(article['category'] for article in articles))
        }
        
        # 保存到JSON文件
        try:
            os.makedirs(self.output_file.parent, exist_ok=True)
            with open(self.output_file, 'w', encoding='utf-8') as f:
                json.dump(blog_data, f, ensure_ascii=False, indent=2)
            
            logging.info(f"成功生成博客数据文件: {self.output_file}")
            logging.info(f"共搜集到 {len(articles)} 篇技术文章")
            
            # 按分类统计
            category_count = {}
            for article in articles:
                category = article['category']
                category_count[category] = category_count.get(category, 0) + 1
            
            logging.info("分类统计:")
            for category, count in category_count.items():
                logging.info(f"  {category}: {count} 篇")
                
        except Exception as e:
            logging.error(f"保存博客数据文件时出错: {e}")
            return False
        
        return True

def main():
    """主函数"""
    collector = BlogCollector()
    success = collector.generate_blog_data()
    
    if success:
        print("✅ 博客文章搜集完成")
    else:
        print("❌ 博客文章搜集失败")
        exit(1)

if __name__ == "__main__":
    main()