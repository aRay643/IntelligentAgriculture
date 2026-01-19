# Dockerfile
FROM python:3.8-slim

# 设置工作目录
WORKDIR /app

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    mosquitto \
    mosquitto-clients \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# 复制 requirements.txt 并安装 Python 依赖
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 复制项目文件
COPY . .

# 创建必要的目录
RUN mkdir -p /app/data /app/logs /app/static/css /app/static/js /app/templates

# 复制静态文件和模板
COPY static/css/style.css /app/static/css/
COPY static/js/main.js /app/static/js/
COPY mosquitto.conf /app/config/

# 创建 templates 目录和 index.html
RUN mkdir -p /app/templates
RUN echo '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>IoT监控系统</title></head><body><h1>IoT传感器数据监控系统</h1><p>系统正在启动...</p></body></html>' > /app/templates/index.html

# 暴露端口
EXPOSE 5000
EXPOSE 1883

# 设置环境变量
ENV PYTHONPATH=/app
ENV WEB_HOST=0.0.0.0
ENV WEB_PORT=5000
ENV MQTT_BROKER=localhost
ENV MQTT_PORT=1883
ENV DB_PATH=/app/data/iot_sensor_data.db

# 启动脚本
COPY docker-entrypoint.sh /app/
RUN chmod +x /app/docker-entrypoint.sh

ENTRYPOINT ["/app/docker-entrypoint.sh"]