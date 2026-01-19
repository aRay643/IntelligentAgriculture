#!/bin/bash
# fix-compatibility.sh - 修复 Docker 版本兼容性

echo "🔧 修复 Docker 版本兼容性问题..."

# 1. 创建兼容性配置文件
cat > docker-compose.compat.yml << 'EOF'
version: '3.7'

services:
  iot-monitor:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: iot-monitor-compat
    ports:
      - "18080:8080"
      - "11883:1883"
    volumes:
      - ./data:/app/data
      - ./logs:/app/logs
      - ./config:/app/config
    environment:
      - WEB_PORT=8080
      - MQTT_PORT=1883
      - COMPOSE_API_VERSION=1.35
    restart: unless-stopped
    command: python main.py
EOF

# 2. 创建简化的 Dockerfile
cat > Dockerfile.compat << 'EOF'
FROM python:3.9-slim

WORKDIR /app

# 复制文件
COPY . .

# 安装依赖
RUN pip install --no-cache-dir -r requirements.txt

# 创建目录
RUN mkdir -p /app/data /app/logs /app/config

EXPOSE 8080 1883

CMD ["python", "main.py"]
EOF

# 3. 创建直接启动脚本
cat > docker-run.sh << 'EOF'
#!/bin/bash
# 直接使用 docker run 启动

# 构建镜像
docker build -f Dockerfile.compat -t iot-sensor-compat .

# 运行容器
docker run -d \
  --name iot-sensor \
  -p 8080:8080 \
  -p 1883:1883 \
  -v $(pwd)/data:/app/data \
  -v $(pwd)/logs:/app/logs \
  --restart unless-stopped \
  iot-sensor-compat

echo "容器已启动"
docker ps
EOF

chmod +x docker-run.sh

echo ""
echo "✅ 兼容性修复完成！"
echo ""
echo "现在可以使用以下命令启动："
echo "  方法1: ./docker-run.sh"
echo "  方法2: docker-compose -f docker-compose.compat.yml up -d"