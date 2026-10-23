FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LC_ALL=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
    bc \
    bison \
    build-essential \
    ca-certificates \
    ccache \
    curl \
    file \
    flex \
    fontconfig \
    g++-multilib \
    gcc-multilib \
    git \
    git-lfs \
    gnupg \
    gperf \
    imagemagick \
    jq \
    lib32readline-dev \
    lib32z1-dev \
    libdw-dev \
    libelf-dev \
    libsdl1.2-dev \
    libssl-dev \
    libxml2 \
    libxml2-utils \
    lz4 \
    lzop \
    pngcrush \
    protobuf-compiler \
    python-is-python3 \
    python3 \
    python3-protobuf \
    repo \
    rsync \
    schedtool \
    squashfs-tools \
    unzip \
    wget \
    xsltproc \
    zip \
    zlib1g-dev \
 && rm -rf /var/lib/apt/lists/*

# Repo needs a git identity in non-interactive environments
RUN git config --global user.name "cnb-build" \
 && git config --global user.email "cnb-build@localhost" \
 && git config --global advice.detachedHead false

WORKDIR /workspace
