#!/bin/bash 
# Run any post_install stuff you want here. 
# This is ran at the end of `immutablue install` and `immutablue update

DOTFILES_GIT="git@gitlab.com:zachpodbielniak/Dotfiles.git"


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
    distrobox enter util -- bash -c "cd $HOME/.dotfiles && /usr/bin/stow --adopt . && git reset --hard HEAD"
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


prepare() {
    prepare_gitlab_ssh_keys
    artifacts_prework
}


install_all_artifacts() {
    install_artifacts_starship
    install_artfifacts_dotfiles
    install_artifacts_fonts
}


prepare
install_all_artifacts

