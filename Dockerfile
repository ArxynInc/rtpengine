# =============================================================================
# rtpengine — multi-arch Docker image (amd64 + arm64 / Graviton-ready)
# =============================================================================
# Fork of drachtio/docker-rtpengine. Differences from upstream:
#   - Base bumped debian:stretch (EOL Jun 2022) → debian:bookworm-slim
#   - sipwise/rtpengine version PINNED via build-arg (was floating HEAD)
#   - Multi-arch published from one Dockerfile via docker buildx + QEMU
#   - Build-deps tracked from sipwise's own debian/control (libiptc-dev,
#     liburing-dev, libpcre2-dev, etc. — bookworm-correct names)
#
# Built and published by .github/workflows/docker-publish.yml on:
#   - every push to main (publishes `:main` + `:latest`)
#   - every v* tag      (publishes `:<version>`)
#   - daily cron via sipwise-version-tracker.yml that bumps RTPENGINE_VERSION
#     when sipwise/rtpengine cuts a new release tag
# =============================================================================

FROM debian:bookworm-slim

# Pinned sipwise/rtpengine release tag. Auto-bumped by
# .github/workflows/sipwise-version-tracker.yml when a new upstream
# release lands. mr13.5.x is the current stable LTS line (mr26 is the
# dev/master line — riskier for prod, kept on stable).
ARG RTPENGINE_VERSION=mr12.5.1.54

LABEL org.opencontainers.image.title="rtpengine" \
      org.opencontainers.image.description="sipwise/rtpengine packaged multi-arch (amd64 + arm64)" \
      org.opencontainers.image.source="https://github.com/ArxynInc/rtpengine" \
      org.opencontainers.image.licenses="GPL-3.0" \
      org.opencontainers.image.version="${RTPENGINE_VERSION}"

# Build + runtime deps in one layer. Names taken directly from
# sipwise/rtpengine's debian/control (Build-Depends section), adjusted
# for bookworm. We keep the build toolchain installed because rtpengine
# loads the kernel module via /usr/lib/xtables/* at runtime — splitting
# build/runtime stages drops headers that runtime introspection still
# needs.
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates curl iproute2 iptables \
    gcc g++ make pkg-config build-essential git gperf zlib1g-dev pandoc \
    libavcodec-dev libavfilter-dev libavformat-dev libavutil-dev libswresample-dev \
    libavcodec-extra libevent-dev libpcap0.8-dev libxmlrpc-core-c3-dev \
    libjson-glib-dev default-libmysqlclient-dev libhiredis-dev libssl-dev \
    libcurl4-openssl-dev libspandsp-dev libwebsockets-dev libcjson-dev \
    libiptc-dev libxtables-dev libmnl-dev libnftnl-dev libpcre2-dev libsystemd-dev \
    libmosquitto-dev libopus-dev libncurses-dev libjwt-dev \
    liburing-dev libglib2.0-dev libbcg729-dev \
  && cd /usr/local/src \
  && git clone --depth 1 --branch "${RTPENGINE_VERSION}" https://github.com/sipwise/rtpengine.git \
  && cd rtpengine/daemon \
  && make \
  # Fail loudly if make didn't produce the daemon binary. Earlier
  # versions of this Dockerfile wrapped the version-check in `|| true`
  # which (due to operator precedence in /bin/sh) accidentally rescued
  # a missing-binary failure and silently shipped a broken image.
  && test -x /usr/local/src/rtpengine/daemon/rtpengine \
  && install -m 0755 /usr/local/src/rtpengine/daemon/rtpengine /usr/local/bin/rtpengine \
  && /usr/local/bin/rtpengine --version \
  && rm -rf /usr/local/src/rtpengine \
  && apt-get purge -y --auto-remove \
    gcc g++ make pkg-config build-essential git pandoc gperf \
  && rm -rf /var/lib/apt/lists/* /var/cache/apt/* /tmp/*

VOLUME ["/tmp"]

EXPOSE 23000-32768/udp 22222/udp

COPY ./entrypoint.sh /entrypoint.sh
COPY ./rtpengine.conf /etc/rtpengine.conf

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

CMD ["rtpengine"]
