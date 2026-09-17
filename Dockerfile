FROM node:22-trixie-slim

ARG CAMOUFOX_VERSION=135.0.1
ARG CAMOUFOX_RELEASE=beta.24
ARG CAMOUFOX_ARCH=x86_64

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    unzip \
    python3 \
    xvfb \
    libgtk-3-0 \
    libdbus-glib-1-2 \
    libxt6 \
    libasound2 \
    libx11-xcb1 \
    libxcomposite1 \
    libxcursor1 \
    libxdamage1 \
    libxfixes3 \
    libxi6 \
    libxrandr2 \
    libxrender1 \
    libxss1 \
    libxtst6 \
    libegl1 \
    libgl1-mesa-dri \
    libgbm1 \
    fonts-liberation \
    fonts-noto-color-emoji \
    fontconfig \
    && rm -rf /var/lib/apt/lists/*

# CamoFox uses Xvfb as its virtual display on Linux. The free Render staging
# setup runs CamoFox separately so it does not share this memory with Trainer.

# The browser build is pinned to the version used by the supplied CamoFox source.
RUN mkdir -p /root/.cache/camoufox \
    && curl -fL -o /tmp/camoufox.zip \
      "https://github.com/daijro/camoufox/releases/download/v${CAMOUFOX_VERSION}-${CAMOUFOX_RELEASE}/camoufox-${CAMOUFOX_VERSION}-${CAMOUFOX_RELEASE}-lin.${CAMOUFOX_ARCH}.zip" \
    && (unzip -q /tmp/camoufox.zip -d /root/.cache/camoufox || true) \
    && rm /tmp/camoufox.zip \
    && chmod -R 755 /root/.cache/camoufox \
    && printf '{"version":"%s","release":"%s"}\n' \
      "${CAMOUFOX_VERSION}" "${CAMOUFOX_RELEASE}" \
      > /root/.cache/camoufox/version.json \
    && test -x /root/.cache/camoufox/camoufox-bin

WORKDIR /opt/camofox

COPY vendor/camofox-browser/package.json vendor/camofox-browser/package-lock.json ./
COPY vendor/camofox-browser/scripts/ ./scripts/
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential \
    && npm ci --omit=dev \
    && apt-get purge -y --auto-remove build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY vendor/camofox-browser/server.js ./
COPY vendor/camofox-browser/lib/ ./lib/
COPY vendor/camofox-browser/mcp/ ./mcp/
COPY vendor/camofox-browser/plugins/persistence/ ./plugins/persistence/
COPY vendor/camofox-browser/docs/ ./docs/
COPY deploy/camofox.config.json ./camofox.config.json

WORKDIR /app

COPY pyproject.toml README.md ./
COPY crumblr_trainer/ ./crumblr_trainer/
COPY scripts/CrumblrHistoryExporter.mq5 ./scripts/CrumblrHistoryExporter.mq5

COPY deploy/start.sh ./deploy/start.sh
COPY deploy/start-camofox.sh ./deploy/start-camofox.sh
RUN chmod 755 /app/deploy/start.sh /app/deploy/start-camofox.sh \
    && mkdir -p /var/data/trainer /var/data/camofox/profiles \
      /var/data/camofox/traces /var/data/camofox/uploads

ENV NODE_ENV=production \
    PYTHONUNBUFFERED=1 \
    HOST=0.0.0.0 \
    PORT=10000 \
    TRAINER_HOME=/var/data/trainer \
    CAMOFOX_EMBEDDED=false \
    CAMOFOX_BASE_URL=http://127.0.0.1:9377 \
    CAMOFOX_BIND_HOST=127.0.0.1 \
    CAMOFOX_PORT=9377 \
    CAMOFOX_PROFILE_DIR=/var/data/camofox/profiles \
    CAMOFOX_TRACES_DIR=/var/data/camofox/traces \
    CAMOFOX_UPLOADS_DIR=/var/data/camofox/uploads \
    CAMOFOX_CRASH_REPORT_ENABLED=false \
    MAX_OLD_SPACE_SIZE=128 \
    HANDLER_TIMEOUT_MS=75000 \
    CAMOFOX_TIMEOUT_SECONDS=90 \
    CAMOFOX_DISABLE_DEFAULT_ADDONS=true \
    MAX_TABS_PER_SESSION=2 \
    MAX_TABS_GLOBAL=4 \
    MAX_CONCURRENT_PER_USER=1 \
    BROWSER_IDLE_TIMEOUT_MS=300000 \
    TAB_INACTIVITY_MS=120000

EXPOSE 10000

HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
    CMD curl -fsS "http://127.0.0.1:${PORT:-10000}/healthz" || exit 1

CMD ["python3", "-m", "crumblr_trainer.api"]
