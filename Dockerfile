FROM ubuntu:18.04 AS build

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && \
    apt install -yqq --no-install-recommends ca-certificates build-essential libc6-dev unzip wget

ARG DUMBINIT_VERSION

WORKDIR /dumb-init-$DUMBINIT_VERSION

RUN wget -q https://github.com/Yelp/dumb-init/archive/refs/tags/v$DUMBINIT_VERSION.zip -O /tmp/dumb-init.zip && \
    unzip -qq -o /tmp/dumb-init.zip -d / && \
    cd /dumb-init-$DUMBINIT_VERSION/ && \
    make

FROM ubuntu:18.04

RUN adduser --system --disabled-password --home /home/gitlab-runner gitlab-runner

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -yqq && \
    apt-get install -yqq --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        curl \
        git \
        wget \
        tzdata \
        openssh-client \
    && rm -rf /var/lib/apt/lists/*

ARG TARGETPLATFORM
ARG DUMBINIT_VERSION

COPY $TARGETPLATFORM/git-lfs /usr/bin/git-lfs
COPY $TARGETPLATFORM/gitlab-runner /usr/bin/gitlab-runner
COPY $TARGETPLATFORM/docker-machine /usr/bin/docker-machine
COPY --from=build /dumb-init-$DUMBINIT_VERSION/dumb-init /usr/bin/dumb-init
COPY ./entrypoint /entrypoint

RUN chmod +x /usr/bin/gitlab-runner && \
    chmod +x /usr/bin/git-lfs && \
    ln -s /usr/bin/gitlab-runner /usr/bin/gitlab-ci-multi-runner && \
    gitlab-runner --version && \
    mkdir -p /etc/gitlab-runner/certs && \
    chmod -R 700 /etc/gitlab-runner && \
    chmod +x /usr/bin/docker-machine && \
    docker-machine --version && \
    chmod +x /usr/bin/dumb-init && \
    dumb-init --version && \
    git-lfs install --skip-repo && \
    git-lfs version && \
    chmod +x /entrypoint

STOPSIGNAL SIGQUIT

VOLUME ["/etc/gitlab-runner", "/home/gitlab-runner"]

ENTRYPOINT ["/usr/bin/dumb-init", "/entrypoint"]

CMD ["run", "--user=gitlab-runner", "--working-directory=/home/gitlab-runner"]