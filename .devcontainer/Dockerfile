FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG FLUTTER_VERSION=3.44.7
ARG ANDROID_CMDLINE_TOOLS_VERSION=15859902

ENV DEBIAN_FRONTEND=noninteractive

ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV ANDROID_HOME=/opt/android-sdk
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV FLUTTER_HOME=/opt/flutter

ENV PATH="${FLUTTER_HOME}/bin:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools:${PATH}"

RUN apt-get update && apt-get install -y \
    ca-certificates \
    clang \
    cmake \
    curl \
    git \
    gnupg \
    jq \
    libglu1-mesa \
    libgtk-3-dev \
    libstdc++-12-dev \
    ninja-build \
    openjdk-17-jdk \
    pkg-config \
    python3 \
    unzip \
    wget \
    xz-utils \
    zip \
    && rm -rf /var/lib/apt/lists/*

# Node.js 22 LTS
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get update \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Flutter SDK
RUN git clone \
    --depth 1 \
    --branch "${FLUTTER_VERSION}" \
    https://github.com/flutter/flutter.git \
    "${FLUTTER_HOME}" \
    && chown -R vscode:vscode "${FLUTTER_HOME}"

# Android command-line tools
RUN mkdir -p "${ANDROID_SDK_ROOT}/cmdline-tools" \
    && curl -fsSL \
      "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip" \
      -o /tmp/android-tools.zip \
    && unzip -q /tmp/android-tools.zip -d /tmp/android-tools \
    && mkdir -p "${ANDROID_SDK_ROOT}/cmdline-tools/latest" \
    && mv /tmp/android-tools/cmdline-tools/* "${ANDROID_SDK_ROOT}/cmdline-tools/latest/" \
    && rm -rf /tmp/android-tools /tmp/android-tools.zip

# Install Android packages required for Flutter Android builds.
RUN yes | sdkmanager --licenses >/dev/null \
    && sdkmanager \
      "platform-tools" \
      "platforms;android-36" \
      "build-tools;36.0.0" \
    && chown -R vscode:vscode "${ANDROID_SDK_ROOT}"

# Agent CLIs.
RUN npm install -g \
    @anthropic-ai/claude-code \
    @openai/codex

USER vscode

RUN flutter config --no-analytics \
    && dart --disable-analytics
