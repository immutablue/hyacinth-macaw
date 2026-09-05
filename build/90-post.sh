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

# Stop Claude Desktop burning a core on software rendering.
#
# Two launcher defaults cost real power on a Wayland desktop:
#
#   1. `_previous_launch_hit_gpu_fatal()` in launcher-common.sh adds
#      `--disable-gpu --disable-software-rasterizer` whenever the previous
#      log section carried a GPU-process crash signature. Chromium spews
#      `gpu_process_host.cc ... error_code=1002` during an ordinary quit,
#      so one noisy exit pins the entire UI to CPU rasterization -- and the
#      latch is deliberately sticky, because the launcher's own "disabling
#      GPU" marker counts as a trigger on the next run. CLAUDE_DISABLE_GPU=0
#      is the documented escape hatch and skips the detection outright.
#
#   2. On Wayland the launcher defaults to `--ozone-platform=x11` purely to
#      keep Quick Entry's Ctrl+Alt+Space working as an X11 key grab. Mutter
#      no longer honours those grabs (upstream #404), so under GNOME the
#      XWayland hop buys nothing and costs a copy per frame.
#      CLAUDE_USE_WAYLAND=1 takes the native path. Drop that one value from
#      claude_desktop_env if a wlroots session ever needs the X11 grab back.
#
# Both names are on the launcher's own env allowlist, but it only reads them
# from the *user's* config dir (~/.config/claude-desktop-debian/environment),
# which an image cannot populate for an existing account -- hence carrying
# them on the Exec line instead. The sed is idempotent so a rebuild against
# an already-patched entry is a no-op. Never fail the build over this: a
# .desktop tweak is not worth a broken image.
claude_desktop_entry='/usr/share/applications/claude-desktop-unofficial.desktop'
claude_desktop_env='env CLAUDE_DISABLE_GPU=0 CLAUDE_USE_WAYLAND=1 '

if [[ -f "${claude_desktop_entry}" ]]
then
    if grep -q '^Exec=env CLAUDE_DISABLE_GPU=' "${claude_desktop_entry}"
    then
        echo 'claude-desktop desktop entry already carries the launcher env; skipping'
    elif ! sed -i "s|^Exec=|Exec=${claude_desktop_env}|" "${claude_desktop_entry}"
    then
        echo 'WARNING: could not patch claude-desktop desktop entry; GPU acceleration stays off' >&2
    fi
fi

# Put the ChatGPT desktop app's window buttons back where GNOME wants them.
# Same story as claude-desktop above: the Linux branch of its per-window
# option table asks for `titleBarStyle: hidden` plus a Chromium window-controls
# overlay for the primary/quick-chat window and for detached chat windows, so
# mutter never decorates them and `org.gnome.desktop.wm.preferences
# button-layout` is ignored. Patch the bundled asar so those windows fall back
# to a GTK-decorated frame; the genuinely chromeless windows (dictation,
# avatar, hotkey overlays) get their framelessness elsewhere and are left
# alone. Never fail the build over this: a ChatGPT update can reshape the
# window options, and a titlebar is not worth a broken image.
chatgpt_asar='/usr/lib/chatgpt/resources/app.asar'
chatgpt_patch="${CUSTOM_INSTALL_DIR}/build/patches/chatgpt-titlebar.py"

if [[ -f "${chatgpt_asar}" ]] && [[ -f "${chatgpt_patch}" ]]
then
    if ! python3 "${chatgpt_patch}" "${chatgpt_asar}"
    then
        echo 'WARNING: chatgpt titlebar patch did not apply; window controls stay on the right' >&2
    fi
fi

# Build docs in case any were added with the image
bash -c "cd /usr/immutablue/docs && hugo build"

# Compile dconf database for system-wide settings
dconf update

