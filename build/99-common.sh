#!/bin/bash
set -euo pipefail
source /usr/libexec/immutablue/immutablue-header.sh

# Where the Immutablue base image installed its own repository. Images built
# from Immutablue's multi-backend design ship the whole build library there
# (build/99-common.sh, backends/lib/interface.sh, backends/<name>/); images
# built from older Immutablue releases only ship packages.yaml, settings and
# docs. Overridable so the backend path can be exercised on a host against a
# checkout of immutablue (see "Testing" in docs/backends.org).
IMMUTABLUE_LIB_DIR="${IMMUTABLUE_LIB_DIR:-/usr/immutablue}"

PACKAGES_YAMLS="$(for f in ${CUSTOM_INSTALL_DIR}/packages/packages.custom-*.yaml; do printf '%s ' ${f}; done)"
MARCH="$(uname -m)"
VERSION="${VERSION:-${FEDORA_VERSION}}"
MODULES_CONF="/etc/modules-load.d/50-immutablue-${NAME}.conf"
IMMUTABLUE_BUILD_OPTIONS_FILE="${IMMUTABLUE_LIB_DIR}/build_options"


get_immutablue_build_options() {
    IFS=',' read -ra entry_array < "${IMMUTABLUE_BUILD_OPTIONS_FILE}"
    for entry in "${entry_array[@]}"
    do
        echo -e "${entry}"
    done 
}

is_option_in_build_options() {
    local option="$1"
    IFS=',' read -ra entry_array < "${IMMUTABLUE_BUILD_OPTIONS_FILE}"
    for entry in "${entry_array[@]}"
    do
        if [[ "${option}" == "${entry}" ]]
        then 
            echo "${TRUE}"
            return 0
        fi
    done 
    echo "${FALSE}"
}

# looks up entries in packages.yaml
# takes into account the version, architecture and build options
get_yaml_array() {
    local key="$1"
    for yaml in ${PACKAGES_YAMLS}
    do
        # Base all
        yq "${key}.all[]" < "${yaml}" 2>/dev/null || true
        # Version specific
        if [[ -n "${VERSION}" ]]; then
            yq "${key}.${VERSION}[]" < "${yaml}" 2>/dev/null || true
        fi
        # Architecture all
        yq "${key}.all_${MARCH}[]" < "${yaml}" 2>/dev/null || true
        # Version + architecture
        if [[ -n "${VERSION}" ]]; then
            yq "${key}.${VERSION}_${MARCH}[]" < "${yaml}" 2>/dev/null || true
        fi
        # Build options
        while read -r option
        do
            # Option all
            yq "${key}_${option}.all[]" < "${yaml}" 2>/dev/null || true
            # Option version
            if [[ -n "${VERSION}" ]]; then
                yq "${key}_${option}.${VERSION}[]" < "${yaml}" 2>/dev/null || true
            fi
            # Option architecture all
            yq "${key}_${option}.all_${MARCH}[]" < "${yaml}" 2>/dev/null || true
            # Option version architecture
            if [[ -n "${VERSION}" ]]; then
                yq "${key}_${option}.${VERSION}_${MARCH}[]" < "${yaml}" 2>/dev/null || true
            fi
        done < <(get_immutablue_build_options)
    done
}


get_immutablue_packages() {
    get_yaml_array '.immutablue.rpm'
}


get_immutablue_pip_packages() {
    get_yaml_array '.immutablue.pip_packages'
}


get_immutablue_packages_to_remove() {
    get_yaml_array '.immutablue.rpm_rm'
}


get_immutablue_package_urls() {
    get_yaml_array '.immutablue.rpm_url'
}


get_immutablue_files_to_remove() {
    get_yaml_array '.immutablue.file_rm'
}


get_immutablue_system_services_to_unmask() {
    get_yaml_array '.immutablue.services_unmask_sys'
}


get_immutablue_system_services_to_disable() {
    get_yaml_array '.immutablue.services_disable_sys'
}


get_immutablue_system_services_to_enable() {
    get_yaml_array '.immutablue.services_enable_sys'
}


get_immutablue_system_services_to_mask() {
    get_yaml_array '.immutablue.services_mask_sys'
}


get_immutablue_user_services_to_unmask() {
    get_yaml_array '.immutablue.services_unmask_user'
}


get_immutablue_user_services_to_disable() {
    get_yaml_array '.immutablue.services_disable_user'
}


get_immutablue_user_services_to_enable() {
    get_yaml_array '.immutablue.services_enable_user'
}


get_immutablue_user_services_to_mask() {
    get_yaml_array '.immutablue.services_mask_user'
}


# -----------------------------------
# Immutablue backends.
#
# Immutablue builds on more than one operating system (a "backend":
# fedora-bootc, gnomeos, arch-bootc, freebsd-be). An image built from that
# design records its backend in ${IMMUTABLUE_LIB_DIR}/backend and ships the
# library that knows how to install packages, add repositories and change
# services on it. When that library is present everything below switches the
# custom build over to it:
#
#   - backend_repo_add, backend_pkg_install, backend_pkg_install_files,
#     backend_pkg_remove, backend_svc, backend_get, backend_has come from
#     ${IMMUTABLUE_LIB_DIR}/backends/lib/interface.sh and the backend's
#     backend.sh, by way of Immutablue's own build/99-common.sh
#   - yq_query, get_yaml_array, dedupe_lines, get_backend_package_list come
#     from the same file and understand the logical 'pkg' lists
#   - the getters this repo's build scripts call are redefined to run those
#     resolvers over the custom packages.custom-*.yaml files
#
# Without it (a base image built from Immutablue master) nothing below runs,
# IMMUTABLUE_HAVE_BACKENDS is 0, and the build scripts take their original
# rpm-ostree/systemctl paths with the getters defined above.
# -----------------------------------
IMMUTABLUE_HAVE_BACKENDS=0

if [[ -f "${IMMUTABLUE_LIB_DIR}/backends/lib/interface.sh" ]]
then
    IMMUTABLUE_HAVE_BACKENDS=1

    # The backend the base image was built with. The recorded file is the
    # truth for a real build; the environment is only consulted when there is
    # no file (testing against a checkout, which has none).
    if [[ -f "${IMMUTABLUE_LIB_DIR}/backend" ]]
    then
        IMMUTABLUE_BACKEND="$(head -n 1 "${IMMUTABLUE_LIB_DIR}/backend")"
    fi
    IMMUTABLUE_BACKEND="${IMMUTABLUE_BACKEND:-fedora-bootc}"
    export IMMUTABLUE_BACKEND

    # Immutablue's 99-common.sh reads ${INSTALL_DIR}/packages.yaml when it is
    # sourced (LTS_VERSION, ZFS_RPM_URL), so INSTALL_DIR must name the
    # directory the library lives in.
    export INSTALL_DIR="${IMMUTABLUE_LIB_DIR}"

    # Immutablue's get_immutablue_build_options reads the build options from
    # the environment, which only exists during Immutablue's own build. In a
    # derived build the file the base image recorded them in is the source,
    # exactly as the getters above read it.
    if [[ -f "${IMMUTABLUE_BUILD_OPTIONS_FILE}" ]]
    then
        IMMUTABLUE_BUILD_OPTIONS="$(head -n 1 "${IMMUTABLUE_BUILD_OPTIONS_FILE}")"
    fi
    IMMUTABLUE_BUILD_OPTIONS="${IMMUTABLUE_BUILD_OPTIONS:-}"
    export IMMUTABLUE_BUILD_OPTIONS

    # Sourcing the library also loads and validates the backend
    # (backend_load) and overwrites a few of the variables set above with
    # Immutablue's own values. MARCH and VERSION come out the same (VERSION is
    # only defaulted, never replaced); MODULES_CONF is this image's file, not
    # Immutablue's, so it is put back.
    custom_modules_conf="${MODULES_CONF}"
    source "${IMMUTABLUE_LIB_DIR}/build/99-common.sh"
    MODULES_CONF="${custom_modules_conf}"
    unset custom_modules_conf


    # Run one of Immutablue's list resolvers over every custom packages yaml.
    #
    # Immutablue's resolvers read a single file, ${PACKAGES_YAML}. This repo
    # has one or more packages.custom-*.yaml files, applied in alphanumeric
    # order, so each becomes PACKAGES_YAML in turn. It is declared 'local':
    # bash's dynamic scoping makes it visible to the resolver called here, and
    # Immutablue's own PACKAGES_YAML is untouched afterwards.
    #
    # The combined output is deduplicated keeping first-seen order, so two
    # files naming the same package install it once.
    #
    # A path that does not exist (the glob matched nothing) is skipped. Any
    # other failure -- a list in a yaml that is a string or a map by mistake --
    # fails the call, so the build stops instead of quietly installing a short
    # package list.
    #
    # param $@: the resolver and its arguments, e.g. get_backend_package_list ''
    # returns: the entries on stdout, one per line; non-zero on a bad yaml
    custom_yaml_resolve() {
        local PACKAGES_YAML
        local yaml

        for yaml in ${PACKAGES_YAMLS}
        do
            if [[ ! -f "${yaml}" ]]
            then
                continue
            fi
            PACKAGES_YAML="${yaml}"
            "$@" || return
        done | dedupe_lines
    }


    # Packages to install: the backend's native list (.immutablue.rpm on
    # fedora-bootc, .pacman on arch-bootc, .freebsd on freebsd-be) plus the
    # logical .immutablue.pkg list resolved to the backend's package names.
    get_immutablue_packages() {
        custom_yaml_resolve get_backend_package_list ''
    }


    # Packages to remove: .immutablue.<pkg_key>_rm plus the logical pkg_rm.
    get_immutablue_packages_to_remove() {
        custom_yaml_resolve get_backend_package_list '_rm'
    }


    # Package files (URLs or paths) to install, from .immutablue.<pkg_key>_url:
    # rpm_url on fedora-bootc as before, pacman_url on arch-bootc, freebsd_url
    # on freebsd-be. A backend without a package manager (gnomeos) has no
    # pkg_key and therefore no package files.
    get_immutablue_package_urls() {
        local pkg_key

        pkg_key="$(backend_get pkg_key)"
        if [[ -z "${pkg_key}" ]]
        then
            return 0
        fi
        custom_yaml_resolve get_yaml_array ".immutablue.${pkg_key}_url"
    }


    # pip packages; 30-install-packages.sh only installs them on backends
    # that provide 'pip'.
    get_immutablue_pip_packages() {
        custom_yaml_resolve get_yaml_array '.immutablue.pip_packages'
    }


    get_immutablue_files_to_remove() {
        custom_yaml_resolve get_yaml_array '.immutablue.file_rm'
    }


    # Service lists accept plain unit names or logical entries resolved by
    # the backend's init system (backend.yaml 'init'), e.g.
    # {name: sshd.service, rc: sshd}: systemd backends use 'name', freebsd-be
    # uses 'rc', and 'rc: null' leaves the service out on rc(8) backends.
    get_immutablue_system_services_to_unmask() {
        custom_yaml_resolve get_yaml_array '.immutablue.services_unmask_sys' "$(backend_get init)"
    }


    get_immutablue_system_services_to_disable() {
        custom_yaml_resolve get_yaml_array '.immutablue.services_disable_sys' "$(backend_get init)"
    }


    get_immutablue_system_services_to_enable() {
        custom_yaml_resolve get_yaml_array '.immutablue.services_enable_sys' "$(backend_get init)"
    }


    get_immutablue_system_services_to_mask() {
        custom_yaml_resolve get_yaml_array '.immutablue.services_mask_sys' "$(backend_get init)"
    }


    get_immutablue_user_services_to_unmask() {
        custom_yaml_resolve get_yaml_array '.immutablue.services_unmask_user' "$(backend_get init)"
    }


    get_immutablue_user_services_to_disable() {
        custom_yaml_resolve get_yaml_array '.immutablue.services_disable_user' "$(backend_get init)"
    }


    get_immutablue_user_services_to_enable() {
        custom_yaml_resolve get_yaml_array '.immutablue.services_enable_user' "$(backend_get init)"
    }


    get_immutablue_user_services_to_mask() {
        custom_yaml_resolve get_yaml_array '.immutablue.services_mask_user' "$(backend_get init)"
    }
fi

