# Dockerfile
FROM python:3.9-slim

# 设置工作目录
WORKDIR /app

# 复制项目文件
COPY requirements.txt .
COPY main.py .
COPY src/ ./src/
COPY templates/ ./templates/
COPY static/ ./static/

# 创建必要的目录
RUN mkdir -p /app/data /app/logs /app/config

# 安装 Python 依赖
RUN pip install --no-cache-dir -r requirements.txt

# 安装 MQTT 代理（mosquitto）
RUN apt-get update && apt-get install -y \
    mosquitto \
    mosquitto-clients \
    && rm -rf /var/lib/apt/lists/*

# 暴露端口
EXPOSE 8080 1883

# 设置启动命令
CMD ["python", "main.py"]