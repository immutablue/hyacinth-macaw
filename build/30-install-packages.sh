#!/bin/bash
set -euxo pipefail 
if [ -f "${CUSTOM_INSTALL_DIR}/build/99-common.sh" ]; then source "${CUSTOM_INSTALL_DIR}/build/99-common.sh"; fi
if [ -f "./99-common.sh" ]; then source "./99-common.sh"; fi


# Get info about which packages to install 
# You likely do not want to edit this rather add 
# packages to your packages yaml
pkgs=$(get_immutablue_packages)
pkg_urls=$(get_immutablue_package_urls)
pip_pkgs=$(get_immutablue_pip_packages)


# With Immutablue's backend library the lists come resolved for the base
# image's backend (see build/99-common.sh): native <pkg_key> lists plus the
# logical pkg lists. Package files go first, then packages by name, as
# before.
#
# On fedora-bootc they are still installed with rpm-ostree, as derived
# images always have been, not with the backend's dnf5: rpm-ostree treats a
# failing %posttrans scriptlet as non-fatal, dnf5 fails the whole
# transaction on it, and RPMs whose scriptlets expect a booted systemd
# (proton-vpn-daemon, for one) would stop builds that work today. The other
# backends use their package manager through backend_pkg_install*.
if [[ "${IMMUTABLUE_HAVE_BACKENDS}" == "1" ]]
then
    # Package files: <pkg_key>_url (rpm_url on fedora-bootc)
    if [[ "$pkg_urls" != "" ]]
    then
        mapfile -t pkg_url_list <<< "${pkg_urls}"
        if [[ "${IMMUTABLUE_BACKEND}" == "fedora-bootc" ]]
        then
            rpm-ostree install "${pkg_url_list[@]}"
        else
            backend_pkg_install_files "${pkg_url_list[@]}"
        fi
    fi

    # Packages by name, in one transaction
    if [[ "$pkgs" != "" ]]
    then
        mapfile -t pkg_list <<< "${pkgs}"
        if [[ "${IMMUTABLUE_BACKEND}" == "fedora-bootc" ]]
        then
            rpm-ostree install "${pkg_list[@]}"
        else
            backend_pkg_install "${pkg_list[@]}"
        fi
    fi

    # pip only on backends that list 'pip' under provides in backend.yaml
    # (fedora-bootc today; Arch's python, for one, is externally managed per
    # PEP 668). Elsewhere the packages are reported and skipped.
    if [[ "$pip_pkgs" != "" ]]
    then
        if [[ "$(backend_has pip)" == "${TRUE}" ]]
        then
            mapfile -t pip_list <<< "${pip_pkgs}"
            pip3 install --prefix=/usr "${pip_list[@]}"
        else
            echo "Backend ${IMMUTABLUE_BACKEND} does not provide pip; skipping pip packages: ${pip_pkgs//$'\n'/ }"
        fi
    fi

    exit 0
fi


# Without the backend library (a base image from Immutablue master):
# rpm-ostree, exactly as before.

# Install rpm_urls
if [[ "$pkg_urls" != "" ]]
then
    rpm-ostree install $(for pkg in $pkg_urls; do printf '%s ' $pkg; done)
fi


# Install immutablue packages
if [[ "$pkgs" != "" ]]
then 
    rpm-ostree install $(for pkg in $pkgs; do printf '%s ' $pkg; done)
fi


# pip package handling
if [[ "$pip_pkgs" != "" ]]
then 
    pip3 install --prefix=/usr $(for pkg in $pip_pkgs; do printf '%s ' $pkg; done)
fi


# Install devpod 
curl -Lo /tmp/devpod "https://github.com/loft-sh/devpod/releases/latest/download/devpod-linux-amd64" && \
    install -c -m 0755 /tmp/devpod /usr/bin && \
    rm -f /tmp/devpod

