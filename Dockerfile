FROM golang:1.16.2-alpine3.12 as build

RUN apk add --no-cache git

ARG GIT_LFS_VERSION
ARG GOARCH
ARG GOOS
ARG GOARM_VERSION
ARG CGO_ENABLED

ENV GOARCH=$GOARCH
ENV GOOS=$GOOS
ENV GOARM_VERSION=$GOARM_VERSION
ENV CGO_ENABLED=$CGO_ENABLED

WORKDIR /git-lfs

RUN git clone --depth 1 --branch v${GIT_LFS_VERSION} https://github.com/git-lfs/git-lfs.git /git-lfs

RUN cd /git-lfs && \
    go build -a -ldflags '-extldflags "-static"' -o bin/git-lfs ./git-lfs.go



FROM ubuntu:18.04

ENV DEBIAN_FRONTEND=noninteractive

RUN adduser --system --disabled-password --home /home/gitlab-runner gitlab-runner

RUN apt update && apt install --no-install-recommends -yqq \
    ca-certificates \
    git \
    openssl \
    tzdata && \
    apt autoremove && \
    apt clean

ARG TARGETPLATFORM

COPY --from=build /git-lfs/bin/git-lfs /usr/bin/git-lfs
COPY $TARGETPLATFORM/gitlab-runner /usr/bin/gitlab-runner
COPY $TARGETPLATFORM/docker-machine /usr/bin/docker-machine
COPY $TARGETPLATFORM/tini /usr/bin/tini
COPY ./entrypoint /entrypoint

RUN chmod +x /usr/bin/gitlab-runner && \
    chmod +x /usr/bin/git-lfs && \
    ln -s /usr/bin/gitlab-runner /usr/bin/gitlab-ci-multi-runner && \
    gitlab-runner --version && \
    mkdir -p /etc/gitlab-runner/certs && \
    chmod -R 700 /etc/gitlab-runner && \
    chmod +x /usr/bin/docker-machine && \
    docker-machine --version && \
    chmod +x /usr/bin/tini && \
    tini --version && \
    git-lfs install --skip-repo && \
    git-lfs version && \
    chmod +x /entrypoint

STOPSIGNAL SIGQUIT

VOLUME ["/etc/gitlab-runner", "/home/gitlab-runner"]

ENTRYPOINT ["/usr/bin/tini","--", "/entrypoint"]

CMD ["run", "--user=gitlab-runner", "--working-directory=/home/gitlab-runner"]