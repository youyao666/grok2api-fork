#!/usr/bin/env sh
set -e

/app/scripts/init_storage.sh

# 如果以 root 运行，修正挂载卷的权限后降权到 appusr
if [ "$(id -u)" = "0" ]; then
    chown -R appusr:appgrp /app/data /app/logs 2>/dev/null || true
    exec su-exec appusr "$@"
fi

exec "$@"
