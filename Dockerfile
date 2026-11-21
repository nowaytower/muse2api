# muse2api —— 多架构镜像（linux/amd64 + linux/arm64）
# 官方镜像由 GitHub Actions 构建：ghcr.io/nowaytower/muse2api
# 本地构建：docker build --build-arg BUILD_SHA=$(git rev-parse --short HEAD) .
ARG PYTHON_IMAGE=python:3.11-slim-bookworm
FROM ${PYTHON_IMAGE}

# 基础环境与 Chromium 安装
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    MUSE2API_HOME=/app \
    MUSE2API_HOST=0.0.0.0 \
    MUSE2API_PORT=18610 \
    MUSE2API_CHROMIUM=/usr/bin/chromium \
    MUSE2API_CDP_PORT=19210 \
    TZ=Asia/Shanghai

ARG BUILD_SHA=
ARG VERSION=dev
ENV MUSE2API_BUILD_SHA=$BUILD_SHA
LABEL org.opencontainers.image.title="muse2api" \
      org.opencontainers.image.description="muse.ai → OpenAI 兼容 API（Chromium 驱动，支持图片/视频/对话）" \
      org.opencontainers.image.source="https://github.com/nowaytower/muse2api" \
      org.opencontainers.image.url="https://github.com/nowaytower/muse2api" \
      org.opencontainers.image.documentation="https://github.com/nowaytower/muse2api#readme" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision=$BUILD_SHA

WORKDIR /app

# 安装 Chromium、中文字体与核心依赖（tzdata：日志/时间按北京时间）
RUN apt-get update && apt-get install -y --no-install-recommends \
    chromium \
    ffmpeg \
    fonts-wqy-zenhei \
    fonts-freefont-ttf \
    procps \
    curl \
    git \
    ca-certificates \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# 安装 Python 依赖
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 复制代码与必要目录
COPY admin.html app.py cdp.py config.py engine.py store.py proxy.py generation_timing.py thumbnails.py version.json ./
COPY deploy/ ./deploy/
COPY extension/ ./extension/
COPY tools/ ./tools/

# 创建持久化数据目录
RUN mkdir -p /app/data/media /app/data/downloads /root/muse2api-profiles

VOLUME ["/app/data"]

EXPOSE 18610

# 健康检查：/healthz 不鉴权、开销极小，编排与反代探活都用它
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
  CMD curl -fsS "http://127.0.0.1:${MUSE2API_PORT}/healthz" || exit 1

CMD ["python", "-m", "uvicorn", "app:app", "--host", "0.0.0.0", "--port", "18610"]
