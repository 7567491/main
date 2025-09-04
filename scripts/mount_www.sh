#!/bin/bash
# 自动挂载www存储桶脚本

LOG_FILE="/home/main/logs/mount_www.log"
MOUNT_POINT="/mnt/www"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# 检查挂载状态
if mountpoint -q "$MOUNT_POINT"; then
    log "www存储桶已挂载"
    exit 0
fi

log "开始挂载www存储桶"

# 挂载www存储桶
if sudo s3fs www "$MOUNT_POINT" \
    -o passwd_file=/etc/passwd-s3fs \
    -o url=https://ap-south-1.linodeobjects.com \
    -o use_path_request_style \
    -o allow_other \
    -o mp_umask=0000 \
    -o dev,suid \
    -o gid=100 \
    -o umask=0000; then
    
    log "www存储桶挂载成功"
    
    # 验证关键文件
    if [[ -f "$MOUNT_POINT/index.html" ]]; then
        log "index.html文件验证成功"
    else
        log "警告：index.html文件不存在"
    fi
else
    log "错误：www存储桶挂载失败"
    exit 1
fi