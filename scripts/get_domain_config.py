#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
域名配置读取辅助脚本
用于Shell脚本读取JSON配置
"""

import json
import sys
import os

CONFIG_FILE = "/home/main/data/domains_config.json"

def get_domain_display_name(domain):
    """获取域名显示名称"""
    if not os.path.exists(CONFIG_FILE):
        return f"🔧 {domain.split('.')[0]}"
    
    try:
        with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
            config = json.load(f)
        
        domain_info = config['domains'].get(domain)
        if domain_info and domain_info.get('enabled', True):
            return domain_info['display_name']
        elif domain_info and not domain_info.get('enabled', True):
            return 'DISABLED'
        else:
            return f"🔧 {domain.split('.')[0]}"
            
    except Exception as e:
        print(f"Error reading config: {e}", file=sys.stderr)
        return f"🔧 {domain.split('.')[0]}"

def is_domain_enabled(domain):
    """检查域名是否启用"""
    if not os.path.exists(CONFIG_FILE):
        return True
    
    try:
        with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
            config = json.load(f)
        
        domain_info = config['domains'].get(domain)
        return domain_info.get('enabled', True) if domain_info else True
        
    except Exception:
        return True

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: get_domain_config.py <action> <domain>")
        print("Actions: display_name, enabled")
        sys.exit(1)
    
    action = sys.argv[1]
    domain = sys.argv[2]
    
    if action == "display_name":
        print(get_domain_display_name(domain))
    elif action == "enabled":
        print("true" if is_domain_enabled(domain) else "false")
    else:
        print("Invalid action")
        sys.exit(1)