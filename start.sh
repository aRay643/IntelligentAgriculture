#!/bin/bash
# start.sh - 一键启动（优先使用简版配置）

echo "🚀 IoT传感器监控系统一键启动"

# 检查使用哪种配置
if [ -f "compose.yml" ]; then
    echo "使用简版 compose.yml 配置"
    docker-compose -f compose.yml down 2>/dev/null || true
    docker-compose -f compose.yml build
    docker-compose -f compose.yml up -d
    docker-compose -f compose.yml ps
elif [ -f "docker-compose.yml" ]; then
    echo "使用 docker-compose.yml 配置"
    docker-compose down 2>/dev/null || true
    docker-compose build
    docker-compose up -d
    docker-compose ps
else
    echo "❌ 未找到配置文件"
    exit 1
fi

echo ""
echo "✅ 系统启动完成！"
echo "访问地址: http://localhost:8080"