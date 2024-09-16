# Base off of Immutablue
ARG FEDORA_VERSION=40
ARG IMMUTABLUE_BASE=immutablue
FROM registry.gitlab.com/immutablue/${IMMUTABLUE_BASE}:${FEDORA_VERSION}
ARG FEDORA_VERSION=40
ARG INSTALL_DIR=/usr/immutablue
ARG NAME=hyacinth-macaw

# COPY in Overrides
COPY ./artifacts/overrides/ /
COPY ./packages/packages.custom-*.yaml ${INSTALL_DIR}/

WORKDIR ${INSTALL_DIR}-build-${NAME}
COPY . .


# Install downloading repos (NO NEED TO EDIT THIS)
# Handle .immutablue.repo_urls[]
RUN set -x && \
    yamls=$(for yaml in ./packages/packages.custom-*.yaml; do printf "%s " $yaml; done) && \
    for yaml in $yamls; do repos=$(yq '.immutablue.repo_urls[].name' < $yaml); for repo in $repos; do curl -Lo "/etc/yum.repos.d/$repo" $(yq ".immutablue.repo_urls[] | select(.name == \"$repo\").url" < $yaml); done; done && \
    for yaml in $yamls; do repos=$(yq ".immutablue.repo_urls_$(uname -m)[].name" < $yaml); for repo in $repos; do curl -Lo "/etc/yum.repos.d/$repo" $(yq ".immutablue.repo_urls_$(uname -m)[] | select(.name == \"$repo\").url" < $yaml); done; done && \
    ostree container commit


# Install RPM from urls (NO NEED TO EDIT THIS)
# Handle .immutablue.rpm_url[]
RUN set -x && \
    pkg_yamls=$(for yaml in ./packages/packages.custom-*.yaml; do printf "%s " $yaml; done) && \
    for yaml in $pkg_yamls; do pkgs=$(cat <(yq '.immutablue.rpm_url[]' < $yaml) <(yq ".immutablue.rpm_url_$(uname -m)[]") < $yaml); for pkg in $pkgs; do curl -Lo /tmp/$(basename "$pkg") "$pkg"; if [ "$pkgs" != "" ]; then rpm-ostree install $(for pkg in $pkgs; do printf '/tmp/%s ' $(basename "$pkg"); done); fi; done; done && \
    ostree container commit


# Install RPM (NO NEED TO EDIT THIS)
# Handle .immutablue.rpm[]
RUN set -x && \
    pkg_yamls=$(for yaml in ./packages/packages.custom-*.yaml; do printf "%s " $yaml; done) && \
    for yaml in $pkg_yamls; do pkgs=$(cat <(yq '.immutablue.rpm[]' < $yaml) <(yq ".immutablue.rpm_$(uname -m)[]" < $yaml)); if [ "" != "$pkgs" ]; then rpm-ostree install $(for pkg in $pkgs; do printf '%s ' $pkg; done); fi; done && \
    ostree container commit


# Remove RPM (NO NEED TO EDIT THIS)
# Handle .immutablue.rpm_rm[]
RUN set -x && \
    pkg_yamls=$(for yaml in ./packages/packages.custom-*.yaml; do printf "%s " $yaml; done) && \
    for yaml in $pkg_yamls; do pkgs=$(cat <(yq '.immutablue.rpm_rm[]' < $yaml) <(yq ".immutablue.rpm_rm_$(uname -m)[]" < $yaml)); [ "" != "$pkgs" ] && rpm-ostree uninstall $(for pkg in $pkgs; do printf '%s ' $pkg; done) || echo "No Uninstalls"; done && \
    ostree container commit


# Remove Build Files (NO NEED TO EDIT THIS)
# Handle .immutablue.file_rm[]
RUN set -x && \
    file_yamls=$(for yaml in ./packages/packages.custom-*.yaml; do printf "%s " $yaml; done) && \
    for yaml in $file_yamls; do files=$(cat <(yq '.immutablue.file_rm[]' < $yaml) <(yq ".immutablue.file_rm_$(uname -m)[]" < $yaml)); for f in $files; do rm -rf "$f"; done; done && \
    ostree container commit


