#!/bin/bash
set -euxo pipefail 
if [ -f "${CUSTOM_INSTALL_DIR}/build/99-common.sh" ]; then source "${CUSTOM_INSTALL_DIR}/build/99-common.sh"; fi
if [ -f "./99-common.sh" ]; then source "./99-common.sh"; fi


# Get info about which packages to install 
# You likely do not want to edit this rather add 
# packages to your packages yaml
pkgs=$(get_immutablue_packages)
pkg_urls=$(get_immutablue_package_urls)
pip_pkgs=$(get_immutablue_pip_packages)


# /opt in a bootc image is a symlink to var/opt, and /var/opt does not exist
# at build time, so rpm cannot unpack any package that ships files under /opt
# (grok-bot's "/opt/Grok Bot", for one): cpio fails with "mkdir failed" and
# rpm-ostree reports only "Error -1 running transaction". opt_prepare swaps
# the symlink for a real directory for the duration of the install.
opt_prepare () {
	if [[ -L /opt ]]
	then
		rm -f /opt
		mkdir -p /opt
	fi
}


# opt_finalize moves whatever the packages put in /opt into /usr/lib/opt
# (where it ships with the image and is replaced on every update), restores
# the /opt -> var/opt symlink, and writes a tmpfiles.d entry per directory so
# /var/opt/<name> links back to /usr/lib/opt/<name> on the booted system.
# Paths inside the packages (and their %post symlinks, e.g. /usr/bin/grok-bot
# -> /opt/Grok Bot/grok-bot) keep resolving through that link.
opt_finalize () {
	local tmpfiles_conf="/usr/lib/tmpfiles.d/hyacinth-macaw-opt.conf"
	local entry
	local name
	local escaped

	# Nothing to do if opt_prepare never replaced the symlink
	if [[ -L /opt ]] || [[ ! -d /opt ]]
	then
		return 0
	fi

	mkdir -p /usr/lib/opt
	shopt -s nullglob dotglob
	for entry in /opt/*
	do
		name="$(basename "${entry}")"
		mv "${entry}" "/usr/lib/opt/${name}"
		# tmpfiles.d(5) splits on whitespace and does not unquote the
		# argument field, so spaces ("Grok Bot") are written as \x20
		escaped="${name// /\\x20}"
		printf 'L+ /var/opt/%s - - - - /usr/lib/opt/%s\n' "${escaped}" "${escaped}" >> "${tmpfiles_conf}"
	done
	shopt -u nullglob dotglob

	rmdir /opt
	ln -s var/opt /opt
}


# With Immutablue's backend library the lists come resolved for the base
# image's backend (see build/99-common.sh): native <pkg_key> lists plus the
# logical pkg lists. Package files go first, then packages by name, as
# before.
#
# On fedora-bootc they are still installed with rpm-ostree, as derived
# images always have been, not with the backend's dnf5: rpm-ostree treats a
# failing %posttrans scriptlet as non-fatal, dnf5 fails the whole
# transaction on it, and RPMs whose scriptlets expect a booted systemd
# (proton-vpn-daemon, for one) would stop builds that work today. The other
# backends use their package manager through backend_pkg_install*.
opt_prepare

if [[ "${IMMUTABLUE_HAVE_BACKENDS}" == "1" ]]
then
    # Package files: <pkg_key>_url (rpm_url on fedora-bootc)
    if [[ "$pkg_urls" != "" ]]
    then
        mapfile -t pkg_url_list <<< "${pkg_urls}"
        if [[ "${IMMUTABLUE_BACKEND}" == "fedora-bootc" ]]
        then
            # Their signing keys first: Fedora 45+ rejects unverified files
            import_rpm_gpg_keys
            rpm-ostree install "${pkg_url_list[@]}"
        else
            backend_pkg_install_files "${pkg_url_list[@]}"
        fi
    fi

    # Packages by name, in one transaction
    if [[ "$pkgs" != "" ]]
    then
        mapfile -t pkg_list <<< "${pkgs}"
        if [[ "${IMMUTABLUE_BACKEND}" == "fedora-bootc" ]]
        then
            rpm-ostree install "${pkg_list[@]}"
        else
            backend_pkg_install "${pkg_list[@]}"
        fi
    fi

    # pip only on backends that list 'pip' under provides in backend.yaml
    # (fedora-bootc today; Arch's python, for one, is externally managed per
    # PEP 668). Elsewhere the packages are reported and skipped.
    if [[ "$pip_pkgs" != "" ]]
    then
        if [[ "$(backend_has pip)" == "${TRUE}" ]]
        then
            mapfile -t pip_list <<< "${pip_pkgs}"
            pip3 install --prefix=/usr "${pip_list[@]}"
        else
            echo "Backend ${IMMUTABLUE_BACKEND} does not provide pip; skipping pip packages: ${pip_pkgs//$'\n'/ }"
        fi
    fi

    opt_finalize
    exit 0
fi


# Without the backend library (a base image from Immutablue master):
# rpm-ostree, exactly as before.

# Install rpm_urls
if [[ "$pkg_urls" != "" ]]
then
    import_rpm_gpg_keys
    rpm-ostree install $(for pkg in $pkg_urls; do printf '%s ' $pkg; done)
fi


# Install immutablue packages
if [[ "$pkgs" != "" ]]
then 
    rpm-ostree install $(for pkg in $pkgs; do printf '%s ' $pkg; done)
fi


# pip package handling
if [[ "$pip_pkgs" != "" ]]
then 
    pip3 install --prefix=/usr $(for pkg in $pip_pkgs; do printf '%s ' $pkg; done)
fi



opt_finalize
