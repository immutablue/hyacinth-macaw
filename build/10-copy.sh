#!/bin/bash
set -euxo pipefail 
if [ -f "${INSTALL_DIR}-build-${NAME}/build/99-common.sh" ]; then source "${INSTALL_DIR}-build-${NAME}/build/99-common.sh"; fi
if [ -f "./99-common.sh" ]; then source "./99-common.sh"; fi

# Copy any files as needed here.
# This often comes from other containers which will
# be added to the Containerfile and then mounted
# in the RUN command
#

# Put in place the correct `/etc/os-release`.
#
# Which file that is belongs to the base image's backend: with Immutablue's
# backend library (IMMUTABLUE_HAVE_BACKENDS, see 99-common.sh) it is
# backend_os_release_path -- /etc/.os-release-<version> on Fedora,
# .os-release-arch on arch-bootc, .os-release-freebsd on freebsd-be; gnomeos
# keeps GNOME OS's own /usr/lib/os-release. Without the library (a base image
# from before the multi-backend design) it is the Fedora file, as before.
#
# A base image that ships Immutablue's scripts/os-release.sh generates that
# file from the base OS's own os-release and the build options, so it is
# rewritten here with Hyacinth Macaw's name and URLs -- the release number,
# SUPPORT_END and the variant then always match the image. The static
# Hyacinth Macaw files in artifacts/overrides/etc/ are the fallback for base
# images without the generator.
# -L as well as -f: on FreeBSD /etc/os-release is a symlink into /var/run.
if [[ "${IMMUTABLUE_HAVE_BACKENDS:-0}" == 1 ]]
then
    os_release="$(backend_os_release_path)"
else
    os_release="/etc/.os-release-${FEDORA_VERSION}"
fi

os_release_generator="${IMMUTABLUE_LIB_DIR:-/usr/immutablue}/scripts/os-release.sh"
if [[ "${IMMUTABLUE_HAVE_BACKENDS:-0}" == 1 ]] && [[ -f "${os_release_generator}" ]]
then
    OS_RELEASE_NAME="Hyacinth Macaw" \
        OS_RELEASE_URL="https://gitlab.com/immutablue/hyacinth-macaw" \
        OS_RELEASE_HOSTNAME="hyacinth-macaw" \
        bash "${os_release_generator}" "$(backend_dir)" \
            "$(head -n 1 "${IMMUTABLUE_LIB_DIR:-/usr/immutablue}/build_options")" "${os_release}"
fi

if [[ -f "/etc/os-release" ]] || [[ -L "/etc/os-release" ]]
then
    unlink "/etc/os-release"
fi

ln -s "${os_release}" "/etc/os-release"

