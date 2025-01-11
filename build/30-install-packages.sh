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

