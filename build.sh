#!/bin/bash

# IMAGE VARIABLES
IMAGE_NAME="xpecex/gitlab-runner"
IMAGE_VER=""
IMAGE_AUTHOR="xPeCex <xpecex@outlook.com>"
IMAGE_VENDOR=$IMAGE_AUTHOR
IMAGE_REF="$(git rev-parse --short HEAD)"
IMAGE_DESC="Gitlab Runner"
IMAGE_BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
IMAGE_URL="https://github.com/xpecex/gitlab-runner"
IMAGE_LICENSE="MIT"
IMAGE_ALT_REF="$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 7 | head -n 1)"

# RELEASES LIST
RELEASES=(
    "14.0.1"
)
# LATEST RELEASE
LATEST_RELEASE=$(curl -s "https://gitlab-runner-downloads.s3.amazonaws.com/latest/index.html" | grep Ref: | cut -d "v" -f 2 | cut -d "<" -f 1)
DOCKER_MACHINE_VERSION=0.16.2
TINI_VERSION=0.19.0
GIT_LFS_VERSION=2.13.3

# GO ENV 
GOOS=linux
CGO_ENABLED=0

# ARCHITECTURE LIST
ARCHS=(
    "linux/amd64"
    "linux/arm/v7"
    "linux/arm64"
)

# CHECK IF DOCKER IS LOGGED
DOCKER_AUTH_TOKEN=$(cat ~/.docker/config.json | grep \"auth\": | xargs | cut -d ':' -f 2 | xargs)
if [ -z "$DOCKER_AUTH_TOKEN" ]; then

    # NOT LOGGED IN
    # Check if $DOCKER_USER is empty
    if [ -z "$DOCKER_USER" ]; then
        # login via command line
        docker login
    else
        # login via command line using --password-stdin
        echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USER" --password-stdin &>/dev/null
    fi

else
    # LOGGED
    echo "Docker appears to be logged in, step skipped."
fi

# ========================= BUILD =========================

# SEARCH RELEASES FOR BUILD
for RELEASE in "${RELEASES[@]}"; do

    # PRINT BUILD INFO
    echo " ========= BUILDING RELEASE: $RELEASE ========= "

    wget -q -O entrypoint https://gitlab.com/gitlab-org/gitlab-runner/-/raw/v${RELEASE}/dockerfiles/alpine/entrypoint

    # Download myst-node .DEB PACKAGE
    for ARCH in "${ARCHS[@]}"; do

        # PRINT DOWNLOAD INFO
        echo "DOWNLOAD PACKAGE $RELEASE FOR $ARCH"

        # CHECK ARCH
        case "$ARCH" in
        linux/amd64)
            RUNNER_ARCH="amd64"
            DOCKER_ARCH="x86_64"
            TINI_ARCH="amd64"
            GOARCH=amd64
            GOARM_VERSION=""
            ;;
        linux/arm/v7)
            RUNNER_ARCH="arm"
            DOCKER_ARCH="armhf"
            TINI_ARCH="armhf"
            GOARCH=arm
            GOARM_VERSION=7
            ;;
        linux/arm64)
            RUNNER_ARCH="arm64"
            DOCKER_ARCH="aarch64"
            TINI_ARCH="arm64"
            GOARCH=arm64
            GOARM_VERSION=""
            ;;
        esac

        # DOWNLOAD FILES
        mkdir -p "$ARCH"
        wget -q -O $ARCH/gitlab-runner -c https://gitlab-runner-downloads.s3.amazonaws.com/v${RELEASE}/binaries/gitlab-runner-linux-${RUNNER_ARCH}
        wget -q -O $ARCH/docker-machine -c https://github.com/docker/machine/releases/download/v${DOCKER_MACHINE_VERSION}/docker-machine-Linux-${DOCKER_ARCH}
        wget -q -O $ARCH/tini -c https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini-static-${TINI_ARCH}

    done

    # PRINT BUILD INFO
    echo "STARTING THE BUILD"

    # Build using BUILDX
    # ADD TAG LATEST IF $RELEASE = $LATEST_RELEASE
    if [ "$RELEASE" = "$LATEST_RELEASE" ]; then
        docker buildx build \
        --push \
        --build-arg GIT_LFS_VERSION="$GIT_LFS_VERSION" \
        --build-arg GOOS="$GOOS" \
        --build-arg CGO_ENABLED="$CGO_ENABLED" \
        --build-arg GOARCH="$GOARCH" \
        --build-arg GOARM_VERSION="$GOARM_VERSION" \
        --cache-from "${IMAGE_NAME}:${IMAGE_VER:-$RELEASE}" \
        --platform "$(echo ${ARCHS[@]} | sed 's/ /,/g')" \
        -t "${IMAGE_NAME}:${IMAGE_VER:-$RELEASE}" \
        -t "${IMAGE_NAME}:latest" \
        .
    else
        docker buildx build \
        --push \
        --build-arg GIT_LFS_VERSION="$GIT_LFS_VERSION" \
        --build-arg GOOS="$GOOS" \
        --build-arg CGO_ENABLED="$CGO_ENABLED" \
        --build-arg GOARCH="$GOARCH" \
        --build-arg GOARM_VERSION="$GOARM_VERSION" \
        --cache-from "${IMAGE_NAME}:${IMAGE_VER:-$RELEASE}" \
        --platform "$(echo ${ARCHS[@]} | sed 's/ /,/g')" \
        -t "${IMAGE_NAME}:${IMAGE_VER:-$RELEASE}" \
        .
    fi

done

# PRINT DEL INFO
echo "Removing files used in build"

# Remove Files
rm -rf linux entrypoint

# PRINT BUILD INFO
echo " ========= build completed successfully ========= "
