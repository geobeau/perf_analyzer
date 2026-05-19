# Minimal perf_analyzer image: client-only (no CUDA, no SDK, no genai-perf).
# Build:  docker build -t perf_analyzer:local --build-arg PERF_ANALYZER_VERSION=test .
#         docker build -t perf_analyzer:local \
#           --build-arg TRITON_CLIENT_REPO_URL=https://github.com/geobeau/client.git \
#           --build-arg GITHUB_TOKEN=<token-for-private-forks> \
#           --build-arg TRITON_CLIENT_REPO_TAG=main \
#           --build-arg TRITON_COMMON_REPO_TAG=main \
#           --build-arg TRITON_CORE_REPO_TAG=main .
# Run:    docker run --rm perf_analyzer:local --help

ARG UBUNTU_VERSION=24.04

FROM ubuntu:${UBUNTU_VERSION} AS builder

ARG PERF_ANALYZER_VERSION=0.0.0
ARG CMAKE_VERSION=3.31.8
ARG TRITON_CLIENT_REPO_TAG=main
ARG TRITON_COMMON_REPO_TAG=main
ARG TRITON_CORE_REPO_TAG=main
ARG TRITON_CLIENT_REPO_URL=
ARG TRITON_COMMON_REPO_URL=
ARG TRITON_CORE_REPO_URL=
ARG GITHUB_TOKEN=

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
    && rm -rf /var/lib/apt/lists/*

RUN curl -LsSf https://apt.kitware.com/kitware-archive.sh | sh

RUN apt-get update && \
    CMAKE_VERSION_FULL=$(apt-cache madison cmake | awk -v v="${CMAKE_VERSION}" '$0 ~ v {print $3; exit}') && \
    apt-get install -y --no-install-recommends \
        cmake=${CMAKE_VERSION_FULL} \
        cmake-data=${CMAKE_VERSION_FULL} \
        build-essential \
        git \
        libssl-dev \
        python3 \
        rapidjson-dev \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . /src

RUN set -eux; \
    if [ -n "${GITHUB_TOKEN}" ]; then \
      git config --global url."https://${GITHUB_TOKEN}@github.com/".insteadOf "https://github.com/"; \
    fi; \
    if [ -n "${TRITON_CLIENT_REPO_URL}" ]; then \
      git config --global url."${TRITON_CLIENT_REPO_URL}".insteadOf "https://github.com/triton-inference-server/client.git"; \
    fi; \
    if [ -n "${TRITON_COMMON_REPO_URL}" ]; then \
      git config --global url."${TRITON_COMMON_REPO_URL}".insteadOf "https://github.com/triton-inference-server/common.git"; \
    fi; \
    if [ -n "${TRITON_CORE_REPO_URL}" ]; then \
      git config --global url."${TRITON_CORE_REPO_URL}".insteadOf "https://github.com/triton-inference-server/core.git"; \
    fi

RUN cmake -B /build -S /src \
        -DCMAKE_BUILD_TYPE=Release \
        -DTRITON_VERSION=${PERF_ANALYZER_VERSION} \
        -DTRITON_CLIENT_REPO_TAG=${TRITON_CLIENT_REPO_TAG} \
        -DTRITON_COMMON_REPO_TAG=${TRITON_COMMON_REPO_TAG} \
        -DTRITON_CORE_REPO_TAG=${TRITON_CORE_REPO_TAG} \
        -DTRITON_ENABLE_GPU=OFF \
        -DTRITON_PACKAGE_PERF_ANALYZER=OFF \
    && cmake --build /build --parallel "$(nproc)"


FROM ubuntu:${UBUNTU_VERSION} AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        libssl3 \
        zlib1g \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/perf_analyzer/src/perf-analyzer-build/perf_analyzer /usr/local/bin/perf_analyzer

ENTRYPOINT ["perf_analyzer"]
CMD ["--help"]
