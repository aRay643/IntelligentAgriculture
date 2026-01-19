#!/bin/bash
# docker-entrypoint.sh

set -e

echo "🚀 启动 IoT 传感器数据监控系统..."

# 启动 Mosquitto MQTT 代理
echo "📡 启动 MQTT 代理 (Mosquitto)..."
mosquitto -c /app/config/mosquitto.conf &

# 等待 MQTT 代理启动
sleep 3

# 检查 MQTT 代理是否运行
if ! pgrep -x "mosquitto" > /dev/null; then
    echo "❌ MQTT 代理启动失败"
    exit 1
fi

echo "✅ MQTT 代理启动成功"

# 启动 Python 应用
echo "🐍 启动 Python Web 应用..."
python main.py