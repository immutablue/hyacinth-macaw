#!/bin/bash
set -euxo pipefail 
if [ -f "${INSTALL_DIR}-build-${NAME}/build/99-common.sh" ]; then source "${INSTALL_DIR}-build-${NAME}/build/99-common.sh"; fi
if [ -f "./99-common.sh" ]; then source "./99-common.sh"; fi

# Copy any files as needed here.
# This often comes from other containers which will
# be added to the Containerfile and then mounted
# in the RUN command
#

# put in place the correct `/etc/os-release`
if [[ -f "/etc/os-release" ]]
then 
    unlink "/etc/os-release"
fi

ln -s "/etc/.os-release-${FEDORA_VERSION}" "/etc/os-release"

