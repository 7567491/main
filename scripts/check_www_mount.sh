#!/bin/bash
# 检查并修复www存储桶挂载状态

MOUNT_POINT="/mnt/www"
LOG_FILE="/home/main/logs/mount_check.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# 检查挂载状态
if ! mountpoint -q "$MOUNT_POINT"; then
    log "警告：www存储桶未挂载，尝试重新挂载"
    /home/main/scripts/mount_www.sh
    
    if mountpoint -q "$MOUNT_POINT"; then
        log "修复成功：www存储桶重新挂载完成"
    else
        log "严重错误：无法挂载www存储桶"
        exit 1
    fi
else
    # 验证关键文件
    if [[ -f "$MOUNT_POINT/index.html" ]]; then
        log "正常：www存储桶挂载且index.html存在"
    else
        log "异常：存储桶已挂载但index.html缺失"
        ls -la "$MOUNT_POINT/" >> "$LOG_FILE"
    fi
fi