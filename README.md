# ArxynInc/rtpengine — multi-arch Docker image

Fork of [drachtio/docker-rtpengine](https://github.com/drachtio/docker-rtpengine) ([MIT](LICENSE)).
Packages [sipwise/rtpengine](https://github.com/sipwise/rtpengine) ([GPL-3.0](https://github.com/sipwise/rtpengine/blob/master/COPYING))
as a Docker image with **both linux/amd64 and linux/arm64** support.

## Why this fork exists

The upstream image `drachtio/rtpengine:latest` only publishes
`linux/amd64`. On 2026-05-27 the ArxynInc EKS fleet attempted a voip
Graviton migration (c6in.large → c7gn.large) and the `rtp-proxy`
DaemonSet crashed with `exec format error` on the arm64 nodes.

`rtpengine` itself is a portable C program and compiles cleanly on
arm64; the issue is purely that drachtio hasn't built a multi-arch
image. This fork uses `docker buildx` + QEMU to produce both
architectures from one Dockerfile.

## Image location

```
ghcr.io/arxyninc/rtpengine:<version>
ghcr.io/arxyninc/rtpengine:latest
```

Published by [`docker-publish.yml`](.github/workflows/docker-publish.yml)
on every push to `main` and every `v*` tag.

## Versioning

The Dockerfile pins the sipwise/rtpengine release tag via the
`RTPENGINE_VERSION` build arg (default: `mr13.5.1.16`). Upstream
release tracking runs daily via
[`sipwise-version-tracker.yml`](.github/workflows/sipwise-version-tracker.yml)
— opens a PR when a new upstream release lands.

This is a **change vs upstream**: drachtio's Dockerfile clones HEAD of
sipwise/rtpengine without pinning, so the image is irreproducible. We
pin so a regression upstream doesn't silently land in prod.

## Differences from upstream drachtio/docker-rtpengine

| | drachtio/docker-rtpengine | ArxynInc/rtpengine |
|---|---|---|
| Architectures | amd64 only | **amd64 + arm64** |
| Base image | `debian:stretch` (EOL Jun 2022) | `debian:bookworm-slim` |
| sipwise version | floating HEAD | pinned via `RTPENGINE_VERSION` ARG |
| Build stages | single | **multi-stage** (build + slim runtime) |
| OCI provenance/SBOM | no | yes (via `docker/build-push-action@v6`) |
| Upstream tracking | none | daily cron auto-bumps via PR |

## Usage in EKS

Replace `drachtio/rtpengine:latest` with
`ghcr.io/arxyninc/rtpengine:<version>` in the `rtp-proxy` DaemonSet.
Once deployed, the voip managed-NG can flip to Graviton:

```
# envs/platform/variables.tf, voip_node_group.dev-ue1:
instance_types = ["c7gn.large"]
ami_type       = "AL2023_ARM_64_STANDARD"
```

Saves ~$30/mo per cluster (~$60/mo dev+prod).

## License

MIT (this Dockerfile + workflows). The packaged binary is GPL-3.0
licensed by upstream sipwise/rtpengine.
