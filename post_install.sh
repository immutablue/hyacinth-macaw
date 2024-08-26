#!/bin/bash 
# Run any post_install stuff you want here. 
# This is ran at the end of `immutablue install` and `immutablue update

DOTFILES_GIT="git@gitlab.com:zachpodbielniak/dotfiles.git"
THEME_GIT="https://github.com/vinceliuice/WhiteSur-gtk-theme.git"


prepare_gitlab_ssh_keys() {
    got_keys=$(grep -P "gitlab\.com" ~/.ssh/known_hosts)
    [ "" == "${got_keys}" ] && ssh-keyscan gitlab.com >> ~/.ssh/known_hosts
}


prepare_artifacts() {
    mkdir -p "$HOME/bin/scripts"
}


install_artifacts_starship() {
	mkdir -p "$HOME/bin/starship"
	curl -Lo /tmp/install_starship.sh https://starship.rs/install.sh
	sh /tmp/install_starship.sh -y -b "$HOME/bin/starship/"
	rm /tmp/install_starship.sh
}


install_artfifacts_dotfiles() {
    [ ! -d "$HOME/.dotfile" ] && git clone "${DOTFILES_GIT}" "$HOME/.dotfiles"
    bash -c "cd $HOME/.dotfiles && git pull" 

    # Kind of dirty
    distrobox enter util -- bash -c "cd $HOME/.dotfiles && /usr/bin/stow --adopt . && git reset --hard HEAD && git submodule update --init --recursive"
}


install_artifacts_fonts() {
    declare -a fonts=(
	    Agave
	    AnonymousPro
	    Arimo
	    AurulentSansMono
	    BigBlueTerminal
	    BitstreamVeraSansMono
	    CascaidaCode
	    CodeNewRoman
	    Cousine
	    DaddyTimeMono
	    DejaVuSansMono
	    DroidSansMono
	    FantasqueSansMono
	    FiraCode
	    FiraMono
	    Go-Mono
	    Gohu
	    Hack
	    Hasklig
	    HeavyData
	    Hermit
	    iA-Writer
	    IBMPlexMono
	    Inconsolate
	    InconsolataGo
	    InconsolataLGC
	    Iosevka
	    JetBrainsMono
	    Lekton
	    LiberationMono
	    Lilex
	    Meslo
	    Monofur
	    Mononoki
	    Monoid
	    MPlus
	    NerdFontsSymbolsOnly
	    Noto
	    OpenDyslexic
	    Overpass
	    ProFont
	    ProggyClean
	    RobotoMono
	    ShareTechMono
	    Terminus
	    Tinos
	    Ubuntu
	    UbuntuMono
	    VictorMono
    )

    version='3.2.1'
    fonts_dir="${HOME}/.local/share/fonts"

    if [[ ! -d "$fonts_dir" ]]; then
        mkdir -p "$fonts_dir"
    fi

    for font in "${fonts[@]}"; do
        zip_file="${font}.zip"
        download_url="https://github.com/ryanoasis/nerd-fonts/releases/download/v${version}/${zip_file}"
        echo "Downloading $download_url"
        curl -Lo "/tmp/${zip_file}" "$download_url" &
    done
    wait


    for font in "${fonts[@]}"; do
        zip_file="${font}.zip"
        echo "unzipping ${zip_file}"
        unzip "/tmp/${zip_file}" -d "$fonts_dir/${font}" -x "*.txt/*" -x "*.md/*" -o &
    done
    wait


    for font in "${fonts[@]}"; do
        zip_file="${font}.zip"
        echo "removing ${zip_file}"
        rm "/tmp/${zip_file}"
    done

    find "$fonts_dir" -name '*Windows Compatible*' -delete

    fc-cache -fv
}


app_settings_ptyxis() {
    local main_key="org.gnome.Ptyxis"
    local profile_key="org.gnome.Ptyxis.Profile:/org/gnome/Ptyxis/Profiles"
    local uuid=$(gsettings get "${main_key}" default-profile-uuid | sed "s/'//g")

    # If I have multiple profile uuids in the future.
    #local uuid_arr=$(gsettings get "${main_key}" profile-uuids)
    #local uuids="$(sed -En 's|[^0-9a-z]*||g; s|([0-9a-z]{32})|\1\n|gp' <<<${uuid_arr})"

    # Main "global" settings
    declare -A settings_kv=(
        [audible-bell]="true"
        [cursor-blink-mode]="system"
        [cursor-shape]="block"
        [default-columns]="uint32 80"
        [default-rows]="uint32 24"
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

    for setting in ${!settings_kv[@]}
    do 
        gsettings set "${main_key}" "${setting}" "${settings_kv[$setting]}"
    done

    for setting in ${!uuid_kv[@]}
    do 
        gsettings set "${profile_key}/${uuid}/" "${setting}" "${uuid_kv[$setting]}"
    done
    
}

app_settings_shell() {
    # shell favorite apps
    gsettings \
        set \
        org.gnome.shell \
        favorite-apps \
        "['io.gitlab.librewolf-community.desktop', 'org.gnome.Ptyxis.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Evolution.desktop', 'org.signal.Signal.desktop']"

    # shell clocks
    gsettings \
        set \
        org.gnome.shell.world-clocks \
        locations \
        "[<(uint32 2, <('Denver', 'KBKF', true, [(0.69307024596694822, -1.8283729951886007)], [(0.69357907925707463, -1.8323287315783685)])>)>, <(uint32 2, <('Linz', 'LOWL', true, [(0.84183047006083411, 0.24754585975676488)], [(0.84299402871326112, 0.24958208303518914)])>)>, <(uint32 2, <('Sydney', 'YSSY', true, [(-0.59253928105207498, 2.6386469349889961)], [(-0.59137572239964786, 2.6392287230418559)])>)>]"

    # shell weather
    gsettings set org.gnome.shell.weather automatic-location "true"
    gsettings \
        set \
        org.gnome.shell.weather \
        locations \
        "[<(uint32 2, <('Lambertville', 'KDUH', true, [(0.7284277019125025, -1.4600600377711768)], [(0.72895215589943418, -1.459583807231478)])>)>]"

}

app_settings_theme() {
    local gtk_theme="WhiteSur-Dark"
    local theme_dir="$HOME/.tmp/theme"
    local background_install_dir="$HOME/.local/share/backgrounds"
    local background_file="file://${background_install_dir}/background.jpg"

    # set background 
    mkdir -p "${background_install_dir}"
    cp /etc/immutablue-build-hyacinth-macaw/artifacts/pictures/background.jpg "${background_install_dir}/background.jpg"
    gsettings set org.gnome.desktop.background picture-uri "${background_file}"
    gsettings set org.gnome.desktop.background picture-uri-dark "${background_file}"

    # Clone
    mkdir -p $HOME/.tmp 
    git clone "${THEME_GIT}" --depth=1 "${theme_dir}"

    # Install theme
    distrobox enter util -- bash -c "cd ${theme_dir} && ./install.sh"


    # Set in bash profile
    is_in_profile=$(grep GTK_THEME $HOME/.bash_profile)
    if [ "" == "$is_in_profile" ]
    then 
        echo "export GTK_THEME=$gtk_theme" >> $HOME/.bash_profile
    fi

    # do the settings (same the `gnome-tweaks` would set)
    gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme"

    # set buttons to left 
    gsettings set org.gnome.desktop.wm.preferences button-layout "close,minimize,maximize:appmenu"

    # set dark mode 
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

    # Flatpak settings 
    flatpak --user override --filesystem=xdg-config/gtk-3.0:ro
    flatpak --user override --filesystem=xdg-config/gtk-4.0:ro
    flatpak --user override --filesystem="$HOME/.themes"
    flatpak --user override --filesystem="$HOME/.icons"
    flatpak --user override "--env=GTK_THEME=$gtk_theme" 
    
    sudo flatpak override --filesystem=xdg-config/gtk-3.0:ro
    sudo flatpak override --filesystem=xdg-config/gtk-4.0:ro
    sudo bash -c "flatpak override --filesystem=\"$HOME/.themes\""
    sudo bash -c "flatpak override --filesystem=\"$HOME/.icons\""
    sudo flatpak override "--env=GTK_THEME=$gtk_theme" 


    # Remove it -- we want a fresh clone every time
    rm -rf "${theme_dir}"
}



prepare() {
    prepare_gitlab_ssh_keys
    artifacts_prework
}


install_all_artifacts() {
    install_artifacts_starship
    install_artfifacts_dotfiles
    install_artifacts_fonts
}

app_settings() {
    app_settings_ptyxis
    app_settings_shell
    app_settings_theme
}


prepare
install_all_artifacts
app_settings

