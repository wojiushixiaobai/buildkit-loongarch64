FROM golang:1.21-buster as builder

ARG BUILDKIT_VERSION=v0.13.0

ENV BUILDKIT_VERSION=${BUILDKIT_VERSION}
ENV GOPROXY=https://goproxy.io
ENV CGO_ENABLED=0

ARG WORKDIR=/opt/buildkit

RUN set -ex; \
    git clone -b ${BUILDKIT_VERSION} --depth=1 https://github.com/moby/buildkit ${WORKDIR}

WORKDIR ${WORKDIR}

RUN set -ex; \
    PKG=github.com/moby/buildkit VERSION=$(git describe --match 'v[0-9]*' --dirty='.m' --always --tags) REVISION=$(git rev-parse HEAD)$(if ! git diff --no-ext-diff --quiet --exit-code; then echo .m; fi); \
    echo "-X ${PKG}/version.Version=${VERSION} -X ${PKG}/version.Revision=${REVISION} -X ${PKG}/version.Package=${PKG}" | tee /tmp/.ldflags; \
    echo -n "${VERSION}" | tee /tmp/.version;

ARG VERIFYFLAGS="--static"
ARG BUILDKIT_DEBUG
ARG GOGCFLAGS=${BUILDKIT_DEBUG:+"all=-N -l"}

RUN set -ex; \
    mkdir -p /opt/dist/bin

RUN set -ex; \
    go build -ldflags "$(cat /tmp/.ldflags)" -o /opt/dist/bin/buildctl ./cmd/buildctl; \
    go build ${GOBUILDFLAGS} -gcflags="${GOGCFLAGS}" -ldflags "$(cat /tmp/.ldflags) -extldflags '-static'" -tags "osusergo netgo static_build seccomp ${BUILDKITD_TAGS}" -o /opt/dist/bin/buildkitd ./cmd/buildkitd; \
    /opt/dist/bin/buildctl --version; \
    /opt/dist/bin/buildkitd --version; \
    cd /opt/dist; \
    tar -czf buildkit-${BUILDKIT_VERSION}-linux-loong64.tar.gz bin/; \
    sha256sum buildkit-${BUILDKIT_VERSION}-linux-loong64.tar.gz > CHECKSUM; \
    rm -rf /opt/dist/bin;

FROM debian:buster-slim

WORKDIR /opt/buildkit

COPY --from=builder /opt/dist /opt/buildkit/dist

VOLUME /dist

CMD cp -rf dist/* /dist/