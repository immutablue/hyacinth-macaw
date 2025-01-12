#!/bin/bash
set -euxo pipefail 
if [ -f "${CUSTOM_INSTALL_DIR}/build/99-common.sh" ]; then source "${CUSTOM_INSTALL_DIR}/build/99-common.sh"; fi
if [ -f "./99-common.sh" ]; then source "./99-common.sh"; fi



install_bins() {
    local temp="/tmp"
    local bin="/usr/bin"

    # These can not be installed via brew on arm64
    if [ "$(uname -m)" == "aarch64" ]
    then 
        # Install bat 
        curl -Lo "${temp}/bat.tar.gz" https://github.com/sharkdp/bat/releases/download/v0.24.0/bat-v0.24.0-aarch64-unknown-linux-gnu.tar.gz 
        pushd "${PWD}" || return
        cd "{$temp}" || return
        tar -xzf bat.tar.gz 
        cp ./bat*/bat "${bin}/"
        rm -rf "./*"
        popd || return

        # Instlall glab 
        curl -Lo "${temp}/glab.tar.gz" https://gitlab.com/gitlab-org/cli/-/releases/v1.46.1/downloads/glab_1.46.1_Linux_arm64.tar.gz
        pushd "${PWD}" || return 
        cd "${temp}" || return 
        tar -xzf glab.tar.gz 
        cp ./bin/glab "${bin}/"
        rm -rf "./*"
        popd || return 

    fi
}


install_fonts() {
    declare -a fonts=(
	    # Agave
	    # AnonymousPro
	    # Arimo
	    # AurulentSansMono
	    # BigBlueTerminal
	    # BitstreamVeraSansMono
	    # CascaidaCode
	    # CodeNewRoman
	    # Cousine
	    # DaddyTimeMono
	    # DejaVuSansMono
	    # DroidSansMono
	    # FantasqueSansMono
	    FiraCode
	    FiraMono
	    # Go-Mono
	    # Gohu
	    Hack
	    # Hasklig
	    # HeavyData
	    # Hermit
	    # iA-Writer
	    # IBMPlexMono
	    # Inconsolate
	    # InconsolataGo
	    # InconsolataLGC
	    # Iosevka
	    # JetBrainsMono
	    # Lekton
	    # LiberationMono
	    # Lilex
	    # Meslo
	    # Monofur
	    # Mononoki
	    # Monoid
	    # MPlus
	    # NerdFontsSymbolsOnly
	    # Noto
	    # OpenDyslexic
	    # Overpass
	    # ProFont
	    # ProggyClean
	    # RobotoMono
	    # ShareTechMono
	    # Terminus
	    # Tinos
	    # Ubuntu
	    # UbuntuMono
	    # VictorMono
    )

    version='3.2.1'
    fonts_dir="/usr/share/fonts"

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


install_cowsay_files() {
    mkdir -p /usr/share/cowsay/cows
    git clone https://github.com/paulkaefer/cowsay-files /tmp/cowsay-files
    cp /tmp/cowsay-files/cows/*.cow /usr/share/cowsay/cows/
    rm -rf /tmp/cowsay-files
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
        install_dir="/usr/share/gnome-shell/extensions/${base_filename:0:-4}"
        curl -Lo "/tmp/${base_filename}" "${extension}"
        mkdir -p "${install_dir}"
        unzip "/tmp/${base_filename}" -d "${install_dir}"
        # gnome-extensions install --force "/tmp/${base_filename}"
        rm -rfv "/tmp/${base_filename}"
    done
}



install_themes() {
    local gtk_theme="WhiteSur-Dark"
    git clone "https://github.com/vinceliuice/WhiteSur-gtk-theme.git" --depth=1 /tmp/white-sur
    for f in /tmp/white-sur/release/*.tar.xz
    do 
        tar -xJf "${f}" -C /usr/share/themes/
    done
    rm -rfv /tmp/white-sur
    
    # Override activities.svg file (top left corner)
    cp "${CUSTOM_INSTALL_DIR}/artifacts/pictures/activities.svg" "/usr/share/themes/${gtk_theme}/gnome-shell/assets/activity.svg"
    cp "${CUSTOM_INSTALL_DIR}/artifacts/pictures/activities.svg" "/usr/share/themes/${gtk_theme}/gnome-shell/assets/activity-white.svg"
}


install_bins
install_fonts
install_cowsay_files
install_extensions
install_themes


# Update dconf
dconf update

# Build docs in case any were added with the image
bash -c "cd /usr/immutablue/docs && hugo build"

