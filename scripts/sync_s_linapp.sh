#!/bin/bash

# s.linapp.fun 动态页面同步脚本
# 将生成的动态页面同步到存储桶

SOURCE_FILE="/home/main/data/s_linapp_index.html"
TARGET_DIR="/mnt/www"
TARGET_FILE="$TARGET_DIR/index.html"
LOG_FILE="/home/main/logs/s_linapp_sync.log"

# 日志函数
log_message() {
    local level="$1"
    local message="$2" 
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# 同步文件到目标目录
sync_to_target() {
    if [[ ! -f "$SOURCE_FILE" ]]; then
        log_message "ERROR" "源文件不存在: $SOURCE_FILE"
        return 1
    fi
    
    log_message "INFO" "开始同步s.linapp.fun页面到目标目录..."
    
    # 确保目标目录存在
    mkdir -p "$TARGET_DIR" 2>/dev/null || true
    
    # 复制文件到目标目录
    if cp "$SOURCE_FILE" "$TARGET_FILE"; then
        log_message "INFO" "文件同步成功: $TARGET_FILE"
        
        # 获取文件大小
        local file_size=$(stat -c%s "$TARGET_FILE" 2>/dev/null || echo "未知")
        log_message "INFO" "同步文件大小: ${file_size} bytes"
        
        return 0
    else
        log_message "ERROR" "文件同步失败"
        return 1
    fi
}

# 主函数
main() {
    log_message "INFO" "======= s.linapp.fun 页面同步开始 ======="
    
    # 创建日志目录
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    
    if sync_to_target; then
        log_message "INFO" "s.linapp.fun 页面同步完成"
        exit 0
    else
        log_message "ERROR" "s.linapp.fun 页面同步失败"
        exit 1
    fi
}

# 运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi