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
DUMBINIT_VERSION=1.2.5
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

    wget -q -O entrypoint https://gitlab.com/gitlab-org/gitlab-runner/-/raw/v${RELEASE}/dockerfiles/runner/ubuntu/entrypoint

    # Download myst-node .DEB PACKAGE
    for ARCH in "${ARCHS[@]}"; do

        # PRINT DOWNLOAD INFO
        echo "DOWNLOAD PACKAGE $RELEASE FOR $ARCH"

        # CHECK ARCH
        case "$ARCH" in
        linux/amd64)
            RUNNER_ARCH="amd64"
            DOCKER_ARCH="x86_64"
            GIT_LFS_ARCH="amd64"
            ;;
        linux/arm/v7)
            RUNNER_ARCH="arm"
            DOCKER_ARCH="armhf"
            GIT_LFS_ARCH="arm"
            ;;
        linux/arm64)
            RUNNER_ARCH="arm64"
            DOCKER_ARCH="aarch64"
            GIT_LFS_ARCH="arm64"
            ;;
        esac

        # DOWNLOAD FILES
        mkdir -p "$ARCH"
        wget -q -O $ARCH/gitlab-runner -c https://gitlab-runner-downloads.s3.amazonaws.com/v${RELEASE}/binaries/gitlab-runner-linux-${RUNNER_ARCH}
        wget -q -O $ARCH/docker-machine -c https://github.com/docker/machine/releases/download/v${DOCKER_MACHINE_VERSION}/docker-machine-Linux-${DOCKER_ARCH}
        wget -q -O $ARCH/git-lfs.tar.gz -c https://github.com/git-lfs/git-lfs/releases/download/v${GIT_LFS_VERSION}/git-lfs-linux-${GIT_LFS_ARCH}-v${GIT_LFS_VERSION}.tar.gz

        tar -xf $ARCH/git-lfs.tar.gz -C $ARCH/
        rm -rf $ARCH/git-lfs.tar.gz

    done



    # PRINT BUILD INFO
    echo "STARTING THE BUILD"

    # Build using BUILDX
    # ADD TAG LATEST IF $RELEASE = $LATEST_RELEASE
    if [ "$RELEASE" = "$LATEST_RELEASE" ]; then
        docker buildx build \
        --push \
        --progress auto \
        --build-arg DUMBINIT_VERSION="$DUMBINIT_VERSION" \
        --cache-from "${IMAGE_NAME}:${IMAGE_VER:-$RELEASE}" \
        --platform "$(echo ${ARCHS[@]} | sed 's/ /,/g')" \
        -t "${IMAGE_NAME}:${IMAGE_VER:-$RELEASE}" \
        -t "${IMAGE_NAME}:latest" \
        .
    else
        docker buildx build \
        --push \
        --progress auto \
        --build-arg DUMBINIT_VERSION="$DUMBINIT_VERSION" \
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
