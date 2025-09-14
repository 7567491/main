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
- **实时安全监控**: `/home/main/scripts/realtime_security_monitor.sh` - 每小时04分和34分执行，30分钟内检测威胁
- **每日安全扫描**: `sudo /home/main/scripts/security_scan.sh` - 每日凌晨4点深度安全审计
- **安全管理工具**: `sudo /home/main/scripts/security_manager.sh [command]`
- **查看封禁IP**: `sudo /home/main/scripts/security_manager.sh list`
- **手动封禁IP**: `sudo /home/main/scripts/security_manager.sh ban <IP>`
- **解封IP**: `sudo /home/main/scripts/security_manager.sh unban <IP>`
- **安全状态**: `sudo /home/main/scripts/security_manager.sh status`
- **安全统计**: `sudo /home/main/scripts/security_manager.sh stats`
- **实时监控日志**: `/home/main/logs/realtime_security.log` - 实时威胁检测记录

### 域名访问量排行系统
- **手动统计排行**: `bash /home/main/scripts/domain_stats_ranking.sh`
- **更新主页卡片**: `python3 /home/main/scripts/update_homepage_simple.py`
- **完整更新流程**: `bash /home/main/scripts/hourly_update.sh`
- **域名配置管理**: `/home/main/data/domains_config.json` - 统一管理所有域名信息
- **配置读取工具**: `/home/main/scripts/get_domain_config.py` - Shell脚本配置读取辅助工具
- **排行数据文件**: `/mnt/www/webclick/latest_top7.json`
- **完整排行**: `/mnt/www/webclick/latest_ranking.json`
- **更新日志**: `/home/main/logs/hourly_update.log`

### Git版本控制系统
- **远程仓库**: https://github.com/7567491/main
- **分支管理**: 主分支 `main`
- **提交历史**: 完整的项目版本记录
- **常用命令**:
  - `git status` - 查看仓库状态
  - `git add .` - 添加所有文件到暂存区
  - `git commit -m "消息"` - 创建提交
  - `git push` - 推送到远程仓库
  - `git pull` - 拉取远程更新
- **忽略文件**: `.gitignore` 已配置排除日志、缓存、敏感文件
- **Token认证**: 使用GitHub Personal Access Token进行身份验证

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
- **主脚本**: `/home/main/scripts/stats_enhanced.sh` - 每小时30分自动执行的增强版访问日志分析
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
- **IP威胁分析脚本**: `/home/main/scripts/attack_analysis.sh` - 过去24小时IP威胁智能分析和分类
- **实时监控脚本**: `/home/main/scripts/realtime_security_monitor.sh` - 每小时04分和34分执行，30分钟内检测威胁
- **每日深度扫描**: `/home/main/scripts/security_scan.sh` - 每日凌晨4点自动执行恶意IP检测
- **安全管理工具**: `/home/main/scripts/security_manager.sh` - 手动管理IP黑名单
- **威胁分析数据**: `/home/main/logs/attack_analysis_24h.json` - 24小时IP威胁分析结果，包含威胁IP和正常IP分类
- **实时监控日志**: `/home/main/logs/realtime_security.log` - 实时威胁检测记录
- **每日扫描日志**: `/home/main/logs/security_scan.log` - 深度扫描日志
- **封禁记录**: `/home/main/logs/banned_ips.log` - IP封禁历史
- **多层防护架构**:
  - **威胁分析层**: 智能IP分类，威胁IP按攻击评分排序，正常IP按访问量展示
  - **实时监控层**: 每30分钟检测，检测延迟从7小时缩短至30分钟
  - **深度扫描层**: 每日全面安全审计，长期威胁分析
  - **自动封禁层**: 检测到威胁立即执行iptables封禁
- **威胁检测模式**: 
  - 敏感文件扫描检测 (.env, .git/, wp-config.php)
  - 目录遍历攻击检测 (%2e%2e, ../, /../../)
  - PHP漏洞扫描检测 (phpinfo, eval-stdin.php, test.php)  
  - 代码注入检测 (allow_url_include, php://input, base64_decode)
  - 恶意工具检测 (Go-http-client, zgrab, nmap, sqlmap, masscan)
  - 高频访问检测 (单IP 30分钟内超过100次请求)
- **IP威胁分析特性**:
  - **智能分类**: 封禁IP归类为威胁，未封禁IP归类为正常
  - **威胁IP展示**: 显示前5个威胁IP，按攻击评分从高到低排序
  - **正常IP展示**: 显示前10个正常访问IP，显示访问次数
  - **关键安全统计**: 总IP数、被封禁IP数、24小时活跃IP数、封禁率等关键指标
  - **地理位置**: 自动获取IP地理位置信息
  - **实时更新**: 统计页面集成威胁分析数据，实时展示安全状态
- **自动化机制**: 
  - 威胁分析：集成到统计系统，每小时30分自动执行
  - 实时监控：每小时04分和34分自动执行
  - 深度扫描：每日4:00执行全面安全审计
  - iptables规则持久化，重启后保持生效
- **Nginx增强防护**: User-Agent过滤、路径遍历阻止、代码注入防护
- **当前防护状态**: 已封禁70个恶意IP，威胁分析+实时监控+深度扫描三重防护体系已激活

### s.linapp.fun 静态文件浏览系统
- **主脚本**: `/home/main/scripts/html_stats.sh` - 每5分钟自动执行HTML文件统计和访问日志分析
- **页面生成**: `/home/main/scripts/generate_dynamic_index.sh` - 动态生成响应式静态文件浏览页面
- **同步脚本**: `/home/main/scripts/sync_s_linapp.sh` - 自动同步生成的页面到存储桶
- **调度脚本**: `/home/main/scripts/s_linapp_scheduler.sh` - 每5分钟统一执行脚本  
- **访问地址**: `https://s.linapp.fun/` - 独立域名的静态文件浏览器
- **数据存储**: `/home/main/data/html_stats/` - HTML统计数据存储目录
- **页面特性**:
  - 🗂️ **智能文件发现** - 自动扫描`/mnt/www/`存储桶中所有HTML文件
  - 📅 **最新文件展示** - 显示6个最新创建的文件（排除index.html）
  - 📋 **完整文件列表** - 按创建时间从早到晚展示所有HTML文件（去除重复）
  - 📊 **访问统计集成** - 基于nginx访问日志的7天访问量统计
  - 🎨 **现代化UI设计** - 响应式卡片布局，渐变背景，毛玻璃效果
  - 🔗 **安全链接** - 所有文件链接使用HTTPS完整URL
  - 📱 **移动端优化** - 完美适配手机和平板设备
  - 🔄 **自动更新** - 每5分钟自动刷新文件列表和访问统计
- **文件分类**: 自动识别博客、工具、管理、广告技术等类别并设置相应图标
- **数据格式**: JSON格式存储文件元数据，包含大小、修改时间、分类、访问次数

### Claude Code Token使用报告系统
- **主脚本**: `/home/main/scripts/claude_usage_html_report.py` - Claude Code使用统计分析和HTML报告生成
- **包装脚本**: `/home/main/scripts/generate_token_report.sh` - 自动化执行和日志记录包装脚本
- **执行日志**: `/home/main/logs/token_report.log` - Token报告生成执行日志
- **访问地址**: `https://linapp.fun/token.html` - Claude Code Token使用统计可视化报告
- **生成时间**: 每日早上5:58和晚上9:58（东8区）自动生成
- **报告特性**:
  - 📊 **全面统计分析** - 30+亿Token使用量、$9000+费用统计、26个活跃用户分析
  - 🕐 **时区修正** - 修正UTC时间转本地时间，消除"半夜活跃"错误现象
  - 📈 **多维度图表** - 每日费用趋势、Token使用量、活跃时间、用户数等可视化
  - 🏆 **用户排名** - Token使用量排行榜，支持费用计算和详细统计
  - 📅 **每日详情** - 完整的每日使用明细，包含活跃小时数、用户数、会话数
  - 🔄 **自动同步** - 生成后自动拷贝到`/mnt/www/token.html`，CDN加速访问
  - 🎨 **专业界面** - Chart.js驱动的交互式图表，响应式现代化设计
- **定价准确性**: 基于Claude Sonnet 4最新定价（$3/1M输入，$15/1M输出）
- **数据来源**: 系统中所有用户的`.claude`目录下的使用记录分析

### 二级域名访问量排行系统 
- **主脚本**: `/home/main/scripts/domain_stats_ranking.sh` - 每小时自动执行域名访问量统计排行
- **更新脚本**: `/home/main/scripts/update_homepage_simple.py` - 主页卡片动态更新脚本
- **调度脚本**: `/home/main/scripts/hourly_update.sh` - 每小时统一执行脚本
- **数据目录**: `/mnt/www/webclick/` - 域名排行数据存储目录
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
- **linapp.fun主页**: `/home/main/site/public/index.html` - 本地智能工具集合主页，访问各种应用服务
- **s.linapp.fun静态浏览**: `/mnt/www/index.html` - 存储桶CDN静态文件浏览器，动态生成HTML文件索引
- **统计页面**: `/mnt/www/stats.html` - CDN加速的独立统计仪表板，专业数据可视化平台
- **排行数据**: `/mnt/www/webclick/` - 域名访问量排行数据存储目录
- **s.linapp.fun数据**: `/home/main/data/html_stats/` + `/home/main/data/s_linapp_index.html` - 静态文件统计和页面
- **数据存储**: `/home/main/logs/` + `/mnt/www/log/` - 本地生成+CDN同步
- **静态资源**: `/mnt/www/` + `/home/main/site/assets/images/` 包含品牌资料和截图
- **内容管理**: `/home/main/content/` 包含专家介绍等内容文件
- **备份管理**: `/home/main/site/backup/` 自动备份主页文件
- **域名分离架构**: 
  - **linapp.fun** - 智能工具应用主页 (本地服务)
  - **s.linapp.fun** - 静态文件浏览器 (存储桶CDN)
- **混合部署**: 主页分离+静态浏览+统计页面+静态资源(存储桶CDN) + 实时数据API(本地服务器)
- **权限管理**: nginx用户可访问logs目录，统计页面正常显示
- **自动化**: 定时任务每小时30分生成统计数据+每小时整点更新排行榜+每5分钟更新静态文件浏览，数据同步到CDN
- **界面设计**: 主页显示项目工具卡片，s.linapp.fun专注静态文件管理，统计功能独立页面专业展示

## 系统状态

### 当前运行状态
- **统计系统**: ✅ 每小时30分自动生成7天+24小时数据
- **实时安全监控**: ✅ 每小时04分和34分执行威胁检测，检测延迟从7小时缩短至30分钟
- **深度安全扫描**: ✅ 每日4点自动扫描，已封禁17个恶意IP
- **排行系统**: ✅ 每小时自动统计域名访问量并更新主页卡片
- **s.linapp.fun静态浏览**: ✅ 每5分钟自动更新HTML文件列表和访问统计，显示42个文件
- **Token使用报告**: ✅ 每日早晚自动生成Claude Code使用统计报告，修正时区问题
- **域名分离**: ✅ linapp.fun(智能工具主页) 与 s.linapp.fun(静态文件浏览) 完全独立运行
- **主页集成**: ✅ 统计面板 + 动态卡片排行无侵入式集成
- **数据同步**: ✅ 统计文件自动同步到CDN存储桶
- **API接口**: ✅ `/logs/` 路由正常，支持异步数据获取
- **域名监控**: ✅ 已监控7个二级域名（已启用），自动发现新域名
- **版本控制**: ✅ Git仓库已初始化，代码已推送到GitHub远程仓库，核心脚本已纳入版本管理
- **多层安全防护**: ✅ 实时监控+深度扫描+自动封禁三重防护体系已激活

### 定时任务配置
```bash
# 统计数据生成（每小时30分）
30 * * * * /home/main/scripts/stats_enhanced.sh >/dev/null 2>&1

# 域名排行更新（每小时整点）
0 * * * * /home/main/scripts/hourly_update.sh >/dev/null 2>&1

# s.linapp.fun静态文件浏览更新（每5分钟）
*/5 * * * * /home/main/scripts/s_linapp_scheduler.sh >/dev/null 2>&1

# Claude Code Token使用报告自动生成（每日早晚）
58 5,21 * * * /home/main/scripts/generate_token_report.sh

# 实时安全监控（每小时04分和34分）
4,34 * * * * /home/main/scripts/realtime_security_monitor.sh >/dev/null 2>&1

# 深度安全扫描（每日4点）
0 4 * * * /home/main/scripts/security_scan.sh >/dev/null 2>&1
```

## Nginx配置
- **linapp.fun配置**: `/etc/nginx/sites-available/linapp-redirect`
  - **主页路由**: `root /home/main/site/public; index index.html;` - 智能工具集合主页
  - **实时数据路由**: `location /logs/ { alias /home/main/logs/; }` - API数据接口
  - **SSL证书**: `/etc/letsencrypt/live/linapp.fun/`
- **s.linapp.fun配置**: `/etc/nginx/sites-available/s.linapp.fun.conf`  
  - **静态浏览路由**: `root /mnt/www; index index.html;` - 存储桶静态文件浏览器
  - **SSL证书**: `/etc/letsencrypt/live/s.linapp.fun/`
- **安全防护**: 屏蔽恶意请求、频率限制、SSL加密、User-Agent过滤
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
- **预计算**: 每小时30分后台生成统计数据，用户访问时零等待

### 安全防护
- **多层防护**: Nginx规则 + 自动IP封禁 + 行为模式检测
- **实时监控**: 8种恶意行为模式检测，自动识别和封禁威胁
- **持久化**: iptables规则持久保存，重启后防护规则不丢失

### 扩展性
- **模块化设计**: 统计系统、安全系统、排行系统、静态文件浏览系统独立运行，互不影响
- **域名分离架构**: linapp.fun和s.linapp.fun完全独立，各自专注特定功能
- **页面分离**: 智能工具主页专注于项目展示，静态浏览专注文件管理，统计功能独立页面专业化展示
- **功能分离**: 主页显示项目卡片和访问量排行，s.linapp.fun专注静态文件管理，统计分析通过独立页面提供完整功能
- **统一配置**: 通过JSON配置文件统一管理域名信息，支持动态启用/禁用
- **自动发现**: 排行系统自动发现新增二级域名，静态浏览系统自动发现新增HTML文件
- **智能适配**: 支持独立日志和主域名路径两种统计模式，支持不同文件类型的图标和分类
- **配置驱动**: 主页卡片、排行系统、静态文件分类完全基于配置文件，便于维护和扩展  
- **数据同步**: 本地生成数据自动同步到CDN，支持高可用部署
- **专业体验**: 统计页面提供企业级数据可视化体验，静态浏览提供现代化文件管理界面
- **响应式设计**: 所有页面完美适配桌面和移动端，提供一致的用户体验

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