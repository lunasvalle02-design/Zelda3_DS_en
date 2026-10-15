# Cross-compilation environment for ROCKNIX (aarch64) — Anbernic RG DS Plus.
#
# x86_64 host (Windows + Docker Desktop/WSL2, Linux or Intel macOS) -> aarch64 binary.
# Debian bookworm: glibc 2.36 (ROCKNIX ships a newer one, so the binary is compatible)
# and SDL2 2.26.x, the branch PortMaster recommends for ports.
FROM debian:bookworm

ARG DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture arm64 \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential crossbuild-essential-arm64 pkg-config \
      libsdl2-dev:arm64 \
      git ca-certificates make file zip unzip patch \
      python3 python3-pil python3-yaml \
      openssh-client rsync sshpass \
 && rm -rf /var/lib/apt/lists/*

# sdl2-config wrapper returning the arm64 SDL2 flags (invoked by the zelda3 Makefile).
RUN printf '%s\n' '#!/bin/sh' \
      'export PKG_CONFIG_LIBDIR=/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/share/pkgconfig' \
      'case "$1" in' \
      '  --cflags) exec pkg-config --cflags sdl2 ;;' \
      '  --libs|--static-libs) exec pkg-config --libs sdl2 ;;' \
      '  --version) exec pkg-config --modversion sdl2 ;;' \
      '  *) echo "usage: sdl2-config --cflags|--libs|--version" >&2; exit 1 ;;' \
      'esac' > /usr/local/bin/sdl2-config \
 && chmod +x /usr/local/bin/sdl2-config

ENV CC=aarch64-linux-gnu-gcc \
    STRIP=aarch64-linux-gnu-strip \
    PKG_CONFIG_LIBDIR=/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/share/pkgconfig

# The volume mounted from Windows belongs to another user: avoid "dubious ownership".
RUN git config --system --add safe.directory "*"

WORKDIR /work
