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

# Put Claude Desktop's window buttons back where GNOME wants them.
# The app makes its main window frameless and draws its own controls, so
# `org.gnome.desktop.wm.preferences button-layout` never applies and the
# buttons sit on the right. Patch the bundled asar so the window falls back
# to a GTK-decorated frame. Never fail the build over this: a Claude Desktop
# update can reshape the window options, and a titlebar is not worth a
# broken image.
claude_desktop_asar='/usr/lib/claude-desktop-unofficial/resources/app.asar'
claude_desktop_patch="${CUSTOM_INSTALL_DIR}/build/patches/claude-desktop-titlebar.py"

if [[ -f "${claude_desktop_asar}" ]] && [[ -f "${claude_desktop_patch}" ]]
then
    if ! python3 "${claude_desktop_patch}" "${claude_desktop_asar}"
    then
        echo 'WARNING: claude-desktop titlebar patch did not apply; window controls stay on the right' >&2
    fi
fi

# Build docs in case any were added with the image
bash -c "cd /usr/immutablue/docs && hugo build"

# Compile dconf database for system-wide settings
dconf update

