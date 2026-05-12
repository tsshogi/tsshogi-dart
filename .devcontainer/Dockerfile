FROM mcr.microsoft.com/devcontainers/base:dev-ubuntu22.04

# Google 公式の Flutter SDK は Linux x64 のみ配布されているため、
# arm64 devcontainer ではコミュニティビルドを利用する。
# https://github.com/zhzhzhy/Flutter-SDK-ARM64
ARG FLUTTER_SDK_TAG=Flutter-SDK-2026-05-11
ENV FLUTTER_SDK_ROOT=/opt/flutter
ENV PATH="${FLUTTER_SDK_ROOT}/bin:${PATH}"

RUN \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  --mount=type=cache,target=/var/cache/apt,sharing=locked \
  apt-get update && apt-get install -y git-filter-repo unzip

RUN \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  --mount=type=cache,target=/var/cache/apt,sharing=locked \
  apt-get update && apt-get install -y --no-install-recommends \
  libasound2 libatk-bridge2.0-0 libatk1.0-0 libatspi2.0-0 \
  libcairo2 libcups2 libdbus-1-3 libdrm2 libgbm1 libglib2.0-0 \
  libnspr4 libnss3 libpango-1.0-0 libwayland-client0 \
  libx11-6 libxcb1 libxcomposite1 libxdamage1 libxext6 \
  libxfixes3 libxkbcommon0 libxrandr2 \
  libfontconfig1 libfreetype6 \
  fonts-liberation fonts-noto-color-emoji fonts-unifont \
  fonts-ipafont-gothic fonts-wqy-zenhei fonts-freefont-ttf

# Flutter SDK (arm64 community build) を /opt/flutter に展開する
RUN set -eux; \
  curl -fsSL -o /tmp/flutter.zip \
    "https://github.com/zhzhzhy/Flutter-SDK-ARM64/releases/download/${FLUTTER_SDK_TAG}/Flutter-SDK-ARM64.zip"; \
  mkdir -p /tmp/flutter-extract; \
  unzip -q /tmp/flutter.zip -d /tmp/flutter-extract; \
  FLUTTER_TOP="$(find /tmp/flutter-extract -mindepth 1 -maxdepth 1 -type d | head -1)"; \
  mv "${FLUTTER_TOP}" "${FLUTTER_SDK_ROOT}"; \
  chown -R vscode:vscode "${FLUTTER_SDK_ROOT}"; \
  rm -rf /tmp/flutter.zip /tmp/flutter-extract; \
  git config --system --add safe.directory "${FLUTTER_SDK_ROOT}"
