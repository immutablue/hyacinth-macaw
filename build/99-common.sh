#!/bin/bash
set -euo pipefail
source /usr/libexec/immutablue/immutablue-header.sh

PACKAGES_YAMLS="$(for f in ${CUSTOM_INSTALL_DIR}/packages/packages.custom-*.yaml; do printf '%s ' ${f}; done)"
MARCH="$(uname -m)"
MODULES_CONF="/etc/modules-load.d/50-immutablue-${NAME}.conf"
IMMUTABLUE_BUILD_OPTIONS_FILE="/usr/immutablue/build_options"


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
# takes into account the architecture and build options
get_yaml_array() {
    local key="$1"
    for yaml in ${PACKAGES_YAMLS}
    do 
        cat <(yq "${key}[]" < "${yaml}") <(yq "${key}_${MARCH}[]" < "${yaml}")
        while read -r option 
        do 
            cat <(yq "${key}_${option}[]" < "${yaml}") <(yq "${key}_${option}_${MARCH}[]" < "${yaml}")
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


