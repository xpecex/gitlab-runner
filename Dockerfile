FROM golang:1.16.2-alpine3.12 as build

ARG GIT_LFS_VERSION
ARG GOARCH
ARG GOOS
ARG GOARM_VERSION
ARG CGO_ENABLED

RUN mkdir -p src/github.com/git-lfs/git-lfs && \
    wget -nv -O /tmp/git-lfs.tar.gz https://github.com/git-lfs/git-lfs/archive/v${GIT_LFS_VERSION}.tar.gz && \
    tar xf  /tmp/git-lfs.tar.gz  -C src/github.com/git-lfs/git-lfs --strip-components 1 && \
    go build -a -ldflags '-extldflags "-static"' -o bin/git-lfs github.com/git-lfs/git-lfs/ 

FROM ubuntu:18.04

RUN adduser --system --disabled-password --home /home/gitlab-runner gitlab-runner

RUN apt update && apt install --no-install-recommends -yqq \
    ca-certificates \
    git \
    openssl \
    tzdata && \
    apt autoremove && \
    apt clean

ARG TARGETPLATFORM

COPY --from=build /go/bin/git-lfs /usr/bin/git-lfs
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