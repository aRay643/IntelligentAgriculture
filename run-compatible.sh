#!/bin/bash
# run-compatible.sh - 兼容旧版本 Docker 的启动脚本

echo "🚀 启动 IoT 传感器监控系统（兼容旧版本 Docker）..."

# 检查是否在正确目录
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ 错误：请在项目目录中运行此脚本"
    exit 1
fi

# 1. 清理旧容器
echo "清理旧容器..."
docker-compose down 2>/dev/null || true

# 2. 使用兼容模式构建（避免使用新特性）
echo "构建镜像..."
COMPOSE_HTTP_TIMEOUT=120 docker-compose build --no-cache

# 3. 启动服务
echo "启动服务..."
docker-compose up -d

# 4. 等待服务启动
echo "等待服务启动..."
sleep 15

# 5. 检查服务状态
echo "检查服务状态..."
docker-compose ps

# 6. 显示访问信息
echo ""
echo "✅ IoT传感器监控系统启动完成！"
echo ""
echo "📊 访问信息:"
echo "   本地访问: http://localhost:8080"
echo "   局域网访问: http://$(hostname -I | awk '{print $1}'):8080"
echo ""
echo "🔧 管理命令:"
echo "   查看日志: docker-compose logs -f"
echo "   停止服务: docker-compose down"
echo "   重启服务: docker-compose restart"