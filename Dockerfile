# =============================================================================
# rtpengine — multi-arch Docker image (amd64 + arm64 / Graviton-ready)
# =============================================================================
# Fork of drachtio/docker-rtpengine. Differences from upstream:
#   - Base bumped debian:stretch (EOL Jun 2022) → debian:bookworm-slim
#   - sipwise/rtpengine version PINNED via build-arg (was floating HEAD)
#   - Multi-arch published from one Dockerfile via docker buildx + QEMU
#   - apt package names adjusted for bookworm
#
# Built and published by .github/workflows/docker-publish.yml on:
#   - every push to main (publishes `:main` + `:latest`)
#   - every v* tag      (publishes `:<version>`)
#   - daily cron via sipwise-version-tracker.yml that bumps RTPENGINE_VERSION
#     when sipwise/rtpengine cuts a new release tag
# =============================================================================

FROM debian:bookworm-slim AS build

# Pinned sipwise/rtpengine version. Bumped automatically by
# .github/workflows/sipwise-version-tracker.yml (opens a PR when a new
# upstream release lands).
ARG RTPENGINE_VERSION=mr13.5.1.16

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates curl iproute2 \
    gcc g++ make pkg-config build-essential git iptables-dev libavfilter-dev \
    libevent-dev libpcap-dev libxmlrpc-core-c3-dev markdown \
    libjson-glib-dev default-libmysqlclient-dev libhiredis-dev libssl-dev \
    libcurl4-openssl-dev libavcodec-extra gperf libspandsp-dev libwebsockets-dev \
    libbencode-perl libcrypt-rijndael-perl libcrypt-openssl-rsa-perl \
    libdigest-hmac-perl libdigest-crc-perl libio-multiplex-perl libio-socket-inet6-perl \
    libnet-interface-perl libsocket6-perl libsystemd-dev libwebsockets-dev \
  && cd /usr/local/src \
  && git clone --depth 1 --branch "${RTPENGINE_VERSION}" https://github.com/sipwise/rtpengine.git \
  && cd rtpengine/daemon \
  && make \
  && cp /usr/local/src/rtpengine/daemon/rtpengine /usr/local/bin/rtpengine \
  && /usr/local/bin/rtpengine --version || true

# -----------------------------------------------------------------------------
# Slim runtime stage — only the binary + runtime libs, no toolchain.
# Cuts image size ~75% vs single-stage and removes the build attack surface.
# -----------------------------------------------------------------------------
FROM debian:bookworm-slim

ARG RTPENGINE_VERSION=mr13.5.1.16
LABEL org.opencontainers.image.title="rtpengine" \
      org.opencontainers.image.description="sipwise/rtpengine packaged multi-arch (amd64 + arm64)" \
      org.opencontainers.image.source="https://github.com/ArxynInc/rtpengine" \
      org.opencontainers.image.licenses="GPL-3.0" \
      org.opencontainers.image.version="${RTPENGINE_VERSION}"

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates iproute2 iptables \
    libavfilter9 libavcodec59 libavformat59 libavutil57 libswresample4 \
    libevent-2.1-7 libpcap0.8 libxmlrpc-core-c3 \
    libjson-glib-1.0-0 libmariadb3 libhiredis0.14 libssl3 \
    libcurl4 libspandsp2 libwebsockets17 libglib2.0-0 \
    libsystemd0 \
  && rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/local/bin/rtpengine /usr/local/bin/rtpengine
COPY ./entrypoint.sh /entrypoint.sh
COPY ./rtpengine.conf /etc/rtpengine.conf

RUN chmod +x /entrypoint.sh

VOLUME ["/tmp"]

EXPOSE 23000-32768/udp 22222/udp

ENTRYPOINT ["/entrypoint.sh"]

CMD ["rtpengine"]
