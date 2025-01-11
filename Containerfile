# Base off of Immutablue
# The only thing you may need to change here
# (other than the change-me stuff) is adding 
# other FROM statements for other containers 
# you would like to copy files from. Which
# you can use the --mount option to RUN below
# to mount that container and add the logic 
# to copy in build/10-copy.sh
ARG FEDORA_VERSION=41
ARG IMMUTABLUE_BASE=immutablue
ARG IMAGE_REGISTRY=quay.io/immutablue


FROM ${IMAGE_REGISTRY}/${IMMUTABLUE_BASE}:${FEDORA_VERSION}


ARG FEDORA_VERSION=41
ARG INSTALL_DIR=/usr/immutablue
ARG NAME=hyacinth-macaw
ARG CUSTOM_INSTALL_DIR=${INSTALL_DIR}-build-${NAME}


# Copy files to appropraite place
COPY ./packages/packages.custom-*.yaml ${INSTALL_DIR}/
WORKDIR ${CUSTOM_INSTALL_DIR}
COPY . .
WORKDIR /
COPY ./artifacts/overrides/ /


# You can add a mount to another container so:
#   --mount=type=bind,from=yq,src=/usr/bin,dst=/mnt-yq \
RUN --mount=type=cache,dst=/var/cache/rpm-ostree \
    set -eux && \
    ls -l ${CUSTOM_INSTALL_DIR}/build && \
    chmod +x ${CUSTOM_INSTALL_DIR}/build/*.sh && \
    for script in ${CUSTOM_INSTALL_DIR}/build/*.sh; do "${script}"; if [[ $? -ne 0 ]]; then echo "ERROR: ${script} failed" && exit 1; fi; done && \
    ostree container commit

