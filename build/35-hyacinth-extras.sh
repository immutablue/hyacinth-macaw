#!/bin/bash
set -euxo pipefail 
if [ -f "${CUSTOM_INSTALL_DIR}/build/99-common.sh" ]; then source "${CUSTOM_INSTALL_DIR}/build/99-common.sh"; fi
if [ -f "./99-common.sh" ]; then source "./99-common.sh"; fi

# Hyacinth Macaw extras that are not packages: installed after the package
# stages, kept out of the template's 30-install-packages.sh (whose backend
# path ends with exit 0) so template updates cherry-pick cleanly.

# Install devpod: Linux only (devpod publishes no FreeBSD binary), and the
# binary for this machine's architecture -- x86_64 is 'amd64', aarch64
# (Asahi) is 'arm64'.
devpod_arch=""
if [[ "$(uname -s)" == "Linux" ]]
then
    case "$(uname -m)" in
        x86_64) devpod_arch="amd64" ;;
        aarch64|arm64) devpod_arch="arm64" ;;
        *) echo "WARNING: no devpod build for $(uname -m); skipping" >&2 ;;
    esac
else
    echo "devpod publishes no build for $(uname -s); skipping"
fi
if [[ -n "${devpod_arch}" ]]
then
    curl -Lo /tmp/devpod "https://github.com/loft-sh/devpod/releases/latest/download/devpod-linux-${devpod_arch}" && \
        install -c -m 0755 /tmp/devpod /usr/bin && \
        rm -f /tmp/devpod
fi

