#!/bin/bash
set -euxo pipefail 
if [ -f "${CUSTOM_INSTALL_DIR}/build/99-common.sh" ]; then source "${CUSTOM_INSTALL_DIR}/build/99-common.sh"; fi
if [ -f "./99-common.sh" ]; then source "./99-common.sh"; fi

# Add Justfile
echo -e 'import "./50-hyacinth-macaw.justfile"\n' >> /usr/libexec/immutablue/just/Justfile

# Migrating to build scripts
echo -e "#!/bin/bash\ntrue\n" > "${CUSTOM_INSTALL_DIR}/post_install.sh"

# Override ptyxis with kitty
if [[ -f /usr/bin/ptyxis ]]
then
    mv /usr/bin/ptyxis /usr/bin/ptyxis-orig
    ln -s /usr/bin/kitty /usr/bin/ptyxis
fi

# Build docs in case any were added with the image
bash -c "cd /usr/immutablue/docs && hugo build"

