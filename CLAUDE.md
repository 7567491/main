# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

请用中文和我对话

## 项目架构

### 核心系统
- **网站架构**: linapp.fun - 6页式单页应用 + 集成统计面板 + 动态排行卡片
- **主要功能**: PDF翻译、云服务可视化、AI生成、行程解析、投票、会议、在线教育
- **数据统计**: 7天+24小时增强版访问统计系统（异步架构）
- **排行系统**: 二级域名访问量自动排行和主页动态更新系统
- **安全防护**: 智能恶意IP检测和自动封禁系统

### 文件组织结构
- `/home/main/site/` - 网站文件目录
  - `/home/main/site/public/` - 公开网站文件
  - `/home/main/site/assets/` - 资源文件
  - `/home/main/site/backup/` - 主页文件备份目录
- `/home/main/scripts/` - Python和Shell脚本
- `/home/main/logs/` - 系统日志文件
- `/home/main/content/` - 内容文件
- `/home/main/data/` - 数据文件
  - `/home/main/data/domains_config.json` - 域名配置文件（统一管理所有二级域名信息）
- `/mnt/www/webclick/` - 域名排行数据存储目录

## 常用命令

### 统计系统
- **生成增强统计**: `bash /home/main/scripts/stats_enhanced.sh`
- **生成基础统计**: `bash /home/main/scripts/stats.sh`
- **主页统计面板**: `https://linapp.fun` (点击"📊 实时访问统计")
- **独立统计页面**: `https://linapp.fun/stats.html` (CDN加速)
- **本地页面**: `/home/main/site/public/stats.html`
- **日志位置**: `/home/main/logs/stats_*.json`
- **API接口**: `https://linapp.fun/logs/` (实时数据)

### 安全防护系统
- **安全扫描和封禁**: `sudo /home/main/scripts/security_scan.sh`
- **安全管理工具**: `sudo /home/main/scripts/security_manager.sh [command]`
- **查看封禁IP**: `sudo /home/main/scripts/security_manager.sh list`
- **手动封禁IP**: `sudo /home/main/scripts/security_manager.sh ban <IP>`
- **解封IP**: `sudo /home/main/scripts/security_manager.sh unban <IP>`
- **安全状态**: `sudo /home/main/scripts/security_manager.sh status`
- **安全统计**: `sudo /home/main/scripts/security_manager.sh stats`

### 域名访问量排行系统
- **手动统计排行**: `bash /home/main/scripts/domain_stats_ranking.sh`
- **更新主页卡片**: `python3 /home/main/scripts/update_homepage_simple.py`
- **完整更新流程**: `bash /home/main/scripts/hourly_update.sh`
- **域名配置管理**: `/home/main/data/domains_config.json` - 统一管理所有域名信息
- **配置读取工具**: `/home/main/scripts/get_domain_config.py` - Shell脚本配置读取辅助工具
- **排行数据文件**: `/mnt/www/webclick/latest_top7.json`
- **完整排行**: `/mnt/www/webclick/latest_ranking.json`
- **更新日志**: `/home/main/logs/hourly_update.log`

### 存储桶操作
- **使用工具**: s3cmd (配置已存在系统变量中)
- **发布目标**: www存储桶 `/mnt/www/` (已挂载)
- **端点**: ap-south-1.linodeobjects.com
- **CDN加速**: 主页及静态资源通过存储桶CDN加速
- **API路由**: `/logs/` 路由到本地实时数据

### 文件命名规范
- 使用极简主义命名: 3-6个字母
- 内容文件放在 `./content/`
- 脚本文件放在 `./scripts/`
- 数据文件放在 `./data/`

## 系统组件

### 增强版访问统计系统
- **主脚本**: `/home/main/scripts/stats_enhanced.sh` - 每分钟自动执行的增强版访问日志分析
- **备用脚本**: `/home/main/scripts/stats.sh` - 原版24小时统计脚本
- **前端入口**: 主页右上角"📊 实时访问统计"按钮 → 跳转到独立统计页面
- **独立页面**: `/mnt/www/stats.html` - 完整的统计仪表板，包含丰富的图表和数据
- **访问地址**: `https://linapp.fun/stats.html` - 专业的数据分析与可视化平台
- **API接口**: `linapp.fun/logs/` - Nginx路由到本地实时数据目录
- **数据流**: Nginx访问日志 → 增强脚本分析 → JSON文件 → CDN同步 → 异步加载
- **异步架构**: 预计算数据，零等待响应，支持高并发访问
- **页面特性**:
  - 🎨 **专业界面设计** - 渐变背景、毛玻璃效果、现代化UI
  - 📊 **7天柱状图趋势** - 每日访问量可视化对比
  - 🕐 **24小时折线图分布** - 每小时访问模式分析
  - 📈 **关键指标卡片** - 24小时访问量、7天总访问量、今日增长、访问高峰
  - 🔄 **自动刷新** - 每60秒更新最新数据
  - 📱 **响应式设计** - 完美适配桌面和移动端
  - 🏠 **导航便捷** - 一键返回主页
- **统计指标**: 
  - **7天数据**: 每日访问量、7天总访问量、平均每日、增长趋势
  - **24小时数据**: 每小时访问量、24小时总访问量、访问高峰
  - **实时数据**: 当前小时访问量、最后更新时间、自动化状态

### 智能安全防护系统
- **主脚本**: `/home/main/scripts/security_scan.sh` - 每日凌晨4点自动执行恶意IP检测
- **管理工具**: `/home/main/scripts/security_manager.sh` - 手动管理IP黑名单
- **日志文件**: `/home/main/logs/security_scan.log` - 扫描日志
- **封禁记录**: `/home/main/logs/banned_ips.log` - IP封禁历史
- **防护特征**: 
  - 路径遍历攻击检测 (/.git/, /.env, %2e%2e)
  - PHP漏洞扫描检测 (phpinfo, eval-stdin.php)  
  - 代码注入检测 (allow_url_include, php://input)
  - 系统探测检测 (/etc/passwd, /bin/sh)
  - WordPress扫描检测 (wp-admin, xmlrpc.php)
  - 数据库探测检测 (phpmyadmin, mysql)
  - 恶意工具检测 (Go-http-client, zgrab, nmap)
  - 高频异常访问检测 (400/404错误20次以上)
- **自动化**: cron定时任务每日4:00执行，iptables规则持久化
- **Nginx增强**: User-Agent过滤、路径遍历阻止、代码注入防护
- **当前状态**: 已封禁11个恶意IP，企业级安全防护已激活

### 二级域名访问量排行系统 
- **主脚本**: `/home/main/scripts/domain_stats_ranking.sh` - 每小时自动执行域名访问量统计排行
- **更新脚本**: `/home/main/scripts/update_homepage_simple.py` - 主页卡片动态更新脚本
- **调度脚本**: `/home/main/scripts/hourly_update.sh` - 每小时统一执行脚本
- **数据目录**: `/mnt/www/webclick/` - 排行数据存储目录
- **执行日志**: `/home/main/logs/hourly_update.log` - 自动化执行日志
- **统计机制**: 
  - 🔍 **智能域名发现** - 自动扫描所有nginx二级域名配置文件
  - 📊 **7天数据统计** - 统计过去7天各域名访问量（含日志轮转）
  - 🏆 **动态排行榜** - 按访问量自动排序生成Top7排行
  - 🔄 **主页自动更新** - 根据排行榜动态更新主页7个项目卡片
  - 💾 **增量备份** - 每次更新前自动备份主页文件
- **数据文件**:
  - `/mnt/www/webclick/latest_top7.json` - 最新Top7数据（主页使用）
  - `/mnt/www/webclick/latest_ranking.json` - 完整排行数据
  - `/mnt/www/webclick/ranking_YYYYMMDD_HHMM.json` - 历史排行文件
  - `/home/main/site/backup/index_backup_*.html` - 主页备份文件
- **监控域名**: 
  - pr.linapp.fun (六页纸AI生成) - 🤖 | Streamlit应用，支持PRFAQ、产品设计等AI生成
  - az.linapp.fun (云服务全球AZ可视化) - 📊 | 云服务区域可视化系统，地图统计和数据分析
  - didi.linapp.fun (滴滴行程解析) - 👥 | 前端+API架构，一键解析滴滴行程为客户名称
  - pdf.linapp.fun (PDF翻译) - 📄 | 专业论文/书籍AI翻译，自带llm api，支持deepseek等
  - vote.linapp.fun (在线投票) - 🗳️ | 投票中午去哪吃饭
  - meet.linapp.fun (会议室预订系统) - 📱 | Akamai会议室预订系统
  - 6page.linapp.fun (六页纸在线课堂) - 📋 | 在线教育系统，课程管理、考试测评、学习跟踪
  - dianbo.linapp.fun (多媒体点播) - 📻 | 已禁用，不参与统计排行
- **自动化流程**: nginx访问日志 → 每小时统计分析 → 生成排行榜 → 更新主页卡片 → CDN同步
- **智能适配**: 
  - 独立日志优先：优先使用各域名独立访问日志
  - 回退机制：若独立日志不存在，从主域名日志提取对应路径访问量
  - 动态发现：自动发现新增的二级域名，无需手动配置

### 部署架构
- **主页**: `/mnt/www/index.html` - 存储桶CDN加速主页 + 动态排行卡片 + 统计入口链接
- **统计页面**: `/mnt/www/stats.html` - CDN加速的独立统计仪表板，专业数据可视化平台
- **排行数据**: `/mnt/www/webclick/` - 域名访问量排行数据存储目录
- **数据存储**: `/home/main/logs/` + `/mnt/www/log/` - 本地生成+CDN同步
- **静态资源**: `/mnt/www/` + `/home/main/site/assets/images/` 包含品牌资料和截图
- **内容管理**: `/home/main/content/` 包含专家介绍等内容文件
- **备份管理**: `/home/main/site/backup/` 自动备份主页文件
- **混合部署**: 主页+统计页面+静态资源(存储桶CDN) + 实时数据API(本地服务器)
- **权限管理**: nginx用户可访问logs目录，统计页面正常显示
- **自动化**: 定时任务每分钟生成统计数据+每小时更新排行榜，数据同步到CDN
- **界面设计**: 主页显示Top7动态排行卡片（含7天访问量），统计功能独立页面专业展示

## 系统状态

### 当前运行状态
- **统计系统**: ✅ 每分钟自动生成7天+24小时数据
- **安全系统**: ✅ 已封禁11个恶意IP，每日4点自动扫描
- **排行系统**: ✅ 每小时自动统计域名访问量并更新主页卡片
- **主页集成**: ✅ 统计面板 + 动态卡片排行无侵入式集成
- **数据同步**: ✅ 统计文件自动同步到CDN存储桶
- **API接口**: ✅ `/logs/` 路由正常，支持异步数据获取
- **域名监控**: ✅ 已监控7个二级域名（已启用），自动发现新域名

### 定时任务配置
```bash
# 统计数据生成（每分钟）
* * * * * /home/main/scripts/stats_enhanced.sh >/dev/null 2>&1

# 域名排行更新（每小时整点）
0 * * * * /home/main/scripts/hourly_update.sh >/dev/null 2>&1

# 安全扫描（每日4点）
0 4 * * * /home/main/scripts/security_scan.sh >/dev/null 2>&1
```

## Nginx配置
- **主配置**: `/etc/nginx/sites-available/linapp-redirect`
- **主页路由**: `root /mnt/www; index index.html;`  
- **实时数据路由**: `location /logs/ { alias /home/main/logs/; }`
- **安全防护**: 屏蔽恶意请求、频率限制、SSL加密
- **增强安全规则**: 
  - User-Agent过滤 (Go-http-client, zgrab等)
  - 路径遍历防护 (%2e%2e, ../)
  - 代码注入防护 (allow_url_include等)
  - 敏感目录保护 (/.git/, /config/, /vendor/)
- **限流配置**: 一般请求10r/s，API请求30r/m

## 技术架构特点

### 性能优化
- **异步数据获取**: 前端通过fetch API获取预生成的JSON文件，响应时间<50ms
- **CDN加速**: 主页和统计页面通过存储桶CDN加速，全球访问优化
- **智能缓存**: 保留15个历史统计版本，支持数据回溯
- **预计算**: 每分钟后台生成统计数据，用户访问时零等待

### 安全防护
- **多层防护**: Nginx规则 + 自动IP封禁 + 行为模式检测
- **实时监控**: 8种恶意行为模式检测，自动识别和封禁威胁
- **持久化**: iptables规则持久保存，重启后防护规则不丢失

### 扩展性
- **模块化设计**: 统计系统、安全系统、排行系统独立运行，互不影响
- **页面分离**: 主页专注于项目展示和排行，统计功能独立页面专业化展示
- **功能分离**: 主页显示项目卡片和访问量排行，统计分析通过独立页面提供完整功能
- **统一配置**: 通过JSON配置文件统一管理域名信息，支持动态启用/禁用
- **自动发现**: 排行系统自动发现新增二级域名，基于nginx配置文件扫描
- **智能适配**: 支持独立日志和主域名路径两种统计模式
- **配置驱动**: 主页卡片和排行系统完全基于配置文件，便于维护和扩展
- **数据同步**: 本地生成数据自动同步到CDN，支持高可用部署
- **专业体验**: 统计页面提供企业级数据可视化体验，Chart.js驱动的专业图表

## 工作原则
- 只做被要求的事情；不多不少
- 优先编辑现有文件而不是创建新文件
- 永远不要主动创建md文件或README
- 使用中文与用户交流

## 项目用户
主项目用户: main (密码: lin1@3)
项目目录: /home/main/
- site: 网站文件
  - public: 公开文件
  - assets: 资源文件
  - backup: 数据库备份
- scripts: 脚本文件
- logs: 日志文件
- content: 内容文件
- data: 数据文件