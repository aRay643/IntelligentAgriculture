#!/bin/bash
# run.sh - Docker 启动脚本（兼容旧版本）

echo "正在启动 IoT 传感器监控系统（兼容模式）..."

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    echo "错误: Docker 未安装"
    exit 1
fi

# 检查 Docker Compose 是否安装
if ! command -v docker-compose &> /dev/null; then
    echo "⚠️  Docker Compose 未安装，尝试安装..."
    sudo apt-get update
    sudo apt-get install -y docker-compose
fi

# 创建必要目录
mkdir -p data logs config static templates

# 检查配置文件是否存在
if [ ! -f "config/mosquitto.conf" ]; then
    echo "创建默认 MQTT 配置文件..."
    mkdir -p config
    echo -e "# mosquitto.conf - 兼容配置\nlistener 1883\nallow_anonymous true" > config/mosquitto.conf
fi

# 设置兼容环境变量
export COMPOSE_HTTP_TIMEOUT=120
export COMPOSE_API_VERSION=1.35

echo "使用兼容模式构建..."
docker-compose build --no-cache

echo "启动服务..."
docker-compose up -d

echo "等待服务启动..."
sleep 10

# 显示状态
docker-compose ps

echo ""
echo "✅ 服务启动完成！"
echo ""
echo "访问地址:"
echo "   本地: http://localhost:8080"
echo "   局域网: http://$(hostname -I | awk '{print $1}'):8080"
echo ""
echo "停止服务: docker-compose down"
echo "查看日志: docker-compose logs -f"