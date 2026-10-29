# Base off of Immutablue
# The only thing you may need to change here
# (other than the change-me stuff) is adding 
# other FROM statements for other containers 
# you would like to copy files from. Which
# you can use the --mount option to RUN below
# to mount that container and add the logic 
# to copy in build/10-copy.sh
#
# This Containerfile builds on the Linux backends of Immutablue:
# fedora-bootc (the default), arch-bootc (make ARCHLINUX=1) and gnomeos.
# FreeBSD images (make FREEBSD=1) use Containerfile.freebsd instead, because
# buildah on FreeBSD has no RUN --mount and the build has to run there.
ARG FEDORA_VERSION=44
ARG IMMUTABLUE_BASE=immutablue
ARG IMAGE_REGISTRY=quay.io/immutablue
ARG BASE_IMAGE=quay.io/immutablue/immutablue:${FEDORA_VERSION}


# FROM ${IMAGE_REGISTRY}/${IMMUTABLUE_BASE}:${FEDORA_VERSION}
FROM ${BASE_IMAGE}


ARG FEDORA_VERSION=44
ARG INSTALL_DIR=/usr/immutablue
ARG NAME=hyacinth-macaw
ARG CUSTOM_INSTALL_DIR=${INSTALL_DIR}-build-${NAME}
ARG IMMUTABLUE_BUILD=true
ARG IMAGE_TAG=immutablue


# Copy files to appropraite place
COPY ./packages/packages.custom-*.yaml ${INSTALL_DIR}/
WORKDIR ${CUSTOM_INSTALL_DIR}
COPY . .
WORKDIR /
COPY ./artifacts/overrides/ /


# You can add a mount to another container so:
#   --mount=type=bind,from=yq,src=/usr/bin,dst=/mnt-yq \
#
# The last step finalizes the image the way its base image's backend needs
# (immutablue_custom_finalize in build/99-common.sh): Immutablue's
# backend_finalize_derived when the base provides it, otherwise
# 'ostree container commit' on fedora-bootc and on base images from Immutablue
# master, 'bootc container lint' on arch-bootc.
RUN --mount=type=cache,dst=/var/cache/rpm-ostree \
    set -eux && \
    ls -l ${CUSTOM_INSTALL_DIR}/build && \
    chmod +x ${CUSTOM_INSTALL_DIR}/build/*.sh && \
    for script in ${CUSTOM_INSTALL_DIR}/build/*.sh; do "${script}"; if [[ $? -ne 0 ]]; then echo "ERROR: ${script} failed" && exit 1; fi; done && \
    bash -c "source '${CUSTOM_INSTALL_DIR}/build/99-common.sh' && immutablue_custom_finalize"

