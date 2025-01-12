#!/bin/bash 
source /usr/libexec/immutablue/immutablue-header.sh
HYACINTH_INSTALL_FILE="${HOME}/.config/.hyacinth_macaw_did_first_setup"
# DOTFILES_GIT="git@gitlab.com:zachpodbielniak/dotfiles.git"
DOTFILES_GIT="https://gitlab.com/zachpodbielniak/dotfiles.git"


# Assume brew is not setup yet or has not been configure this early in login
if [ "$(uname -m)" == "x86_64" ]
then
    export PATH="$HOME/../linuxbrew/.linuxbrew/bin:$PATH"
fi


setup_flatpak() {
    local gtk_theme="WhiteSur-Dark"

    # Flatpak settings 
    flatpak --user override --filesystem=xdg-config/gtk-3.0:ro
    flatpak --user override --filesystem=xdg-config/gtk-4.0:ro
    flatpak --user override --filesystem="/usr/share/themes"
    flatpak --user override --filesystem="/usr/share/icons"
    flatpak --user override "--env=GTK_THEME=$gtk_theme" 
    
    sudo flatpak override --filesystem=xdg-config/gtk-3.0:ro
    sudo flatpak override --filesystem=xdg-config/gtk-4.0:ro
    sudo bash -c "flatpak override --filesystem=\"/usr/share/themes\""
    sudo bash -c "flatpak override --filesystem=\"/usr/share/icons\""
    sudo flatpak override "--env=GTK_THEME=$gtk_theme" 
}


prepare_gitlab_ssh_keys() {
    got_keys=$(grep -P "gitlab\.com" ~/.ssh/known_hosts)
    [[ "" == "${got_keys}" ]] && ssh-keyscan gitlab.com >> ~/.ssh/known_hosts
}


prepare_artifacts() {
    mkdir -p "$HOME/bin/scripts"
}


install_dotfiles() {
    local dotfiles_dir="${HOME}/.dotfiles"
    [[ ! -d "${dotfiles_dir}" ]] && git clone "${DOTFILES_GIT}" "${dotfiles_dir}"
    bash -c "cd ${dotfiles_dir} && git pull" 

    # Kind of dirty
    bash -c "cd ${dotfiles_dir} && stow --adopt . && git reset --hard HEAD && git submodule update --init --recursive"
}


setup_bat() {
    # bat theme 
    # https://github.com/catppuccin/bat
    bat 2>/dev/null >/dev/null 
    if [[ $? -eq 0 ]] && [[ ! -d "$(bat --config-dir)/themes" ]]
    then
        mkdir -p "$(bat --config-dir)/themes"

        wget -P "$(bat --config-dir)/themes" https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20Latte.tmTheme
        wget -P "$(bat --config-dir)/themes" https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20Frappe.tmTheme
        wget -P "$(bat --config-dir)/themes" https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20Macchiato.tmTheme
        wget -P "$(bat --config-dir)/themes" https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20Mocha.tmTheme

        bat cache --build
    fi
}


app_settings_ptyxis() {
    local main_key="org.gnome.Ptyxis"
    local profile_key="org.gnome.Ptyxis.Profile:/org/gnome/Ptyxis/Profiles"
    local uuid=""

    uuid=$(gsettings get "${main_key}" default-profile-uuid | sed "s/'//g")

    # If I have multiple profile uuids in the future.
    #local uuid_arr=$(gsettings get "${main_key}" profile-uuids)
    #local uuids="$(sed -En 's|[^0-9a-z]*||g; s|([0-9a-z]{32})|\1\n|gp' <<<${uuid_arr})"

    # Main "global" settings
    declare -A settings_kv=(
        [audible-bell]="true"
        [cursor-blink-mode]="system"
        [cursor-shape]="block"
        [default-columns]="uint32 140"
        [default-rows]="uint32 40"
        [enable-a11y]="false"
        [font-name]="Hack Nerd Font Mono 10"
        [interface-style]="system"
        [new-tab-position]="last"
        [restore-session]="true"
        [restore-window-size]="true"
        [scrollbar-policy]="system"
        [text-blink-mode]="always"
        [toast-on-copy-clipboard]="true"
        [use-system-font]="false"
        [visual-bell]="true"
        [visual-process-leader]="true"
        [window-size]="(uint32 223, uint32 65)"
    )

    # Per profile settings
    declare -A uuid_kv=(
        [backspace-binding]="ascii-delete"
        [bold-is-bright]="true"
        [cjk-ambiguous-width]="narrow"
        [custom-command]=""
        [default-container]="session"
        [delete-binding]="delete-sequence"
        [exit-action]="close"
        [label]="My Profile"
        [login-shell]="false"
        [opacity]="1.0"
        [palette]="Catppuccin Mocha"
        [preserve-container]="always"
        [preserve-directory]="safe"
        [scroll-on-keystroke]="true"
        [scroll-on-output]="false"
        [scrollback-lines]="10000"
        [use-custom-command]="false"
        [use-proxy]="true"
    )

    for setting in "${!settings_kv[@]}"
    do 
        gsettings set "${main_key}" "${setting}" "${settings_kv[$setting]}"
    done

    for setting in "${!uuid_kv[@]}"
    do 
        gsettings set "${profile_key}/${uuid}/" "${setting}" "${uuid_kv[$setting]}"
    done
    
}


install_extensions() {
    declare -a extensions_download=(
        "https://github.com/Schneegans/Desktop-Cube/releases/download/v26/desktop-cube@schneegans.github.com.zip"
        # "https://extensions.gnome.org/extension-data/search-lighticedman.github.com.v27.shell-extension.zip"
        "https://extensions.gnome.org/extension-data/tailscale-statusmaxgallup.github.com.v33.shell-extension.zip"
        "https://github.com/Leleat/Tiling-Assistant/releases/download/v48/tiling-assistant@leleat-on-github.shell-extension.zip"
        "https://extensions.gnome.org/extension-data/unblanksun.wxggmail.com.v31.shell-extension.zip"
        "https://extensions.gnome.org/extension-data/rounded-window-cornersfxgn.v3.shell-extension.zip"
    )

    for extension in "${extensions_download[@]}"
    do 
        local base_filename=""
        base_filename=$(basename "${extension}")
        curl -Lo "/tmp/${base_filename}" "${extension}"
        gnome-extensions install --force "/tmp/${base_filename}"
    done
}


app_settings_enable_extensions() {
    declare -a extensions_enable=(
        "appindicatorsupport@rgcjonas.gmail.com"
        "dash-to-dock@micxgx.gmail.com"
        "gsconnect@andyholmes.github.io"
        "user-theme@gnome-shell-extensions.gcampax.github.com"
        "desktop-cube@schneegans.github.com"
        "search-light@icedman.github.com"
        "tailscale-status@maxgallup.github.com"
        "tiling-assistant@leleat-on-github"
        "unblank@sun.wxg@gmail.com"
    )

    if [[ "$(immutablue_build_is_asahi)" != "${FALSE}" ]]
    then 
        extensions_enable+=("rounded-window-corners@fxgn")
    fi


    declare -a extensions_disable=(
        "background-logo@fedorahosted.org"
        "launch-new-instance@gnome-shell-extensions.gcampax.github.com"
        "places-menu@gnome-shell-extensions.gcampax.github.com"
        "window-list@gnome-shell-extensions.gcampax.github.com"
    )

    
    for extension in "${extensions_enable[@]}"
    do 
        gnome-extensions enable "${extension}"
    done
    
    for extension in "${extensions_disable[@]}"
    do 
        gnome-extensions disable "${extension}"
    done
}




setup_desktop_background() {
    local background_install_dir="$HOME/.local/share/backgrounds"
    local background_file="file://${background_install_dir}/background.jpg"

    # set background 
    mkdir -p "${background_install_dir}"
    cp ${EXPECTED_INSTALL_DIR}/artifacts/pictures/background.jpg "${background_install_dir}/background.jpg"
    gsettings set org.gnome.desktop.background picture-uri "${background_file}"
    gsettings set org.gnome.desktop.background picture-uri-dark "${background_file}"
}


if [[ ! -f "${HYACINTH_INSTALL_FILE}" ]]
then 
    prepare_gitlab_ssh_keys
    prepare_artifacts
    install_dotfiles
    setup_bat
    setup_flatpak
    install_extensions
    app_settings_enable_extensions
    touch "${HYACINTH_INSTALL_FILE}"
fi


# default apps
gsettings \
    set \
    org.gnome.shell \
    favorite-apps \
    "['io.gitlab.librewolf-community.desktop', 'kitty.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Evolution.desktop', 'org.signal.Signal.desktop']"


