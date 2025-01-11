#!/bin/bash
set -euxo pipefail 
if [ -f "${CUSTOM_INSTALL_DIR}/build/99-common.sh" ]; then source "${CUSTOM_INSTALL_DIR}/build/99-common.sh"; fi
if [ -f "./99-common.sh" ]; then source "./99-common.sh"; fi


# Uninstall packages listed in packages yaml
# You likely do not want to edit this rather 
# add packages to remove in your packages yaml
pkgs=$(get_immutablue_packages_to_remove)


if [[ "$pkgs" != "" ]]
then 
    rpm-ostree uninstall $(for pkg in $pkgs; do printf '%s ' $pkg; done)
fi

