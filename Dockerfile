# ============================================================
#  Stage 1 — builder: install Python deps via uv
# ============================================================
FROM python:3.13-alpine AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TZ=Asia/Shanghai \
    UV_PROJECT_ENVIRONMENT=/opt/venv

ENV PATH="$UV_PROJECT_ENVIRONMENT/bin:$PATH"

RUN apk add --no-cache \
    tzdata \
    ca-certificates \
    build-base \
    linux-headers \
    libffi-dev \
    openssl-dev \
    curl-dev \
    cargo \
    rust

WORKDIR /app

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

COPY pyproject.toml uv.lock ./

RUN uv sync --frozen --no-dev --no-install-project \
    && find /opt/venv -type d -name "__pycache__" -prune -exec rm -rf {} + \
    && find /opt/venv -type f -name "*.pyc" -delete \
    && find /opt/venv -type d -name "tests" -prune -exec rm -rf {} + \
    && find /opt/venv -type d -name "test" -prune -exec rm -rf {} + \
    && find /opt/venv -type d -name "testing" -prune -exec rm -rf {} + \
    && find /opt/venv -type f -name "*.so" -exec strip --strip-unneeded {} + || true \
    && rm -rf /root/.cache /tmp/uv-cache

# ============================================================
#  Stage 2 — runtime: lean production image
# ============================================================
FROM python:3.13-alpine

LABEL maintainer="chenyme" \
      description="Grok2API - OpenAI-compatible Grok reverse proxy"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TZ=Asia/Shanghai \
    VIRTUAL_ENV=/opt/venv \
    SERVER_HOST=0.0.0.0 \
    SERVER_PORT=8000 \
    SERVER_WORKERS=1

ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN apk add --no-cache \
    tzdata \
    ca-certificates \
    libffi \
    openssl \
    libgcc \
    libstdc++ \
    libcurl \
    tini \
    curl \
    && addgroup -S appgrp \
    && adduser -S appusr -G appgrp

WORKDIR /app

COPY --from=builder /opt/venv /opt/venv

COPY config.defaults.toml ./
COPY app ./app
COPY _public ./_public
COPY main.py ./
COPY scripts ./scripts

RUN mkdir -p /app/data /app/logs \
    && chown -R appusr:appgrp /app/data /app/logs \
    && chmod +x /app/scripts/entrypoint.sh \
    && sed -i 's/\r$//' /app/scripts/*.sh

EXPOSE 8000

USER appusr

# tini 作为 PID 1，正确处理信号转发
ENTRYPOINT ["tini", "--", "/app/scripts/entrypoint.sh"]

CMD ["sh", "-c", "granian --interface asgi --host ${SERVER_HOST:-0.0.0.0} --port ${SERVER_PORT:-8000} --workers ${SERVER_WORKERS:-1} main:app"]
