FROM ubuntu:18.04 AS build

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update -yqq && \
    apt install -yqq --no-install-recommends build-essential libc6-dev git

ARG DUMBINIT_VERSION

WORKDIR /dumb-init

RUN git clone --depth 1 --branch v${DUMBINIT_VERSION} https://github.com/Yelp/dumb-init.git /dumb-init && \
    cd /dumb-init && \
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

COPY $TARGETPLATFORM/git-lfs /usr/bin/git-lfs
COPY $TARGETPLATFORM/gitlab-runner /usr/bin/gitlab-runner
COPY $TARGETPLATFORM/docker-machine /usr/bin/docker-machine
COPY --from=build /dumb-init/dumb-init /usr/bin/dumb-init
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