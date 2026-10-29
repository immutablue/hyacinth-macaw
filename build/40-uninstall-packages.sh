#!/bin/bash
set -euxo pipefail 
if [ -f "${CUSTOM_INSTALL_DIR}/build/99-common.sh" ]; then source "${CUSTOM_INSTALL_DIR}/build/99-common.sh"; fi
if [ -f "./99-common.sh" ]; then source "./99-common.sh"; fi


# Uninstall packages listed in packages yaml
# You likely do not want to edit this rather 
# add packages to remove in your packages yaml
pkgs=$(get_immutablue_packages_to_remove)


# With Immutablue's backend library (see build/99-common.sh) removal goes
# through the base image's package manager, and only for packages that are
# actually installed: dnf5, pacman and pkg all fail the whole transaction on
# an absent package, which would stop the build over something that was
# wanted gone anyway. Anything skipped is reported, because a permanently
# absent entry is dead configuration worth noticing.
if [[ "${IMMUTABLUE_HAVE_BACKENDS}" == "1" ]]
then
    installed_pkgs=()
    for pkg in $pkgs
    do
        if [[ "$(backend_pkg_installed "${pkg}")" == "${TRUE}" ]]
        then
            installed_pkgs+=("${pkg}")
        else
            echo "Skipping removal of '${pkg}': not installed"
        fi
    done

    if [[ ${#installed_pkgs[@]} -gt 0 ]]
    then
        backend_pkg_remove "${installed_pkgs[@]}"
    fi

    exit 0
fi


# Without the backend library (a base image from Immutablue master):
# rpm-ostree, exactly as before.
if [[ "$pkgs" != "" ]]
then 
    rpm-ostree uninstall $(for pkg in $pkgs; do printf '%s ' $pkg; done)
fi

