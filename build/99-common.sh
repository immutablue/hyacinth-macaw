#!/bin/bash
set -euo pipefail
source /usr/libexec/immutablue/immutablue-header.sh

PACKAGES_YAMLS="$(for f in ${CUSTOM_INSTALL_DIR}/packages/packages.custom-*.yaml; do printf '%s ' ${f}; done)"
MARCH="$(uname -m)"
MODULES_CONF="/etc/modules-load.d/50-immutablue-${NAME}.conf"


get_yaml_array() {
    local key="$1"
    for yaml in ${PACKAGES_YAMLS}
    do
        cat <(yq "${key}[]" < "${yaml}") <(yq "${key}_${MARCH}[]" < "${yaml}")

        if [[ "$(immutablue_build_is_nucleus)" == "${TRUE}" ]]
        then
            cat <(yq "${key}_nucleus[]" < "${yaml}") <(yq "${key}_nucleus_${MARCH}[]" < "${yaml}")
        fi

        if [[ "$(immutablue_build_is_kuberblue)" == "${TRUE}" ]]
        then
            cat <(yq "${key}_kuberblue[]" < "${yaml}") <(yq "${key}_kuberblue_${MARCH}[]" < "${yaml}")
        fi
        
        if [[ "$(immutablue_build_is_trueblue)" == "${TRUE}" ]]
        then
            cat <(yq "${key}_trueblue[]" < "${yaml}") <(yq "${key}_trueblue_${MARCH}[]" < "${yaml}")
        fi

        if [[ "$(immutablue_build_is_lts)" == "${TRUE}" ]]
        then
            cat <(yq "${key}_lts[]" < "${yaml}") <(yq "${key}_lts_${MARCH}[]" < "${yaml}")
        fi

        if [[ "$(immutablue_build_is_cyan)" == "${TRUE}" ]]
        then
            cat <(yq "${key}_cyan[]" < "${yaml}") <(yq "${key}_cyan_${MARCH}[]" < "${yaml}")
        fi

        if [[ "$(immutablue_build_is_asahi)" == "${TRUE}" ]]
        then
            cat <(yq "${key}_asahi[]" < "${yaml}") <(yq "${key}_asahi_${MARCH}[]" < "${yaml}")
        fi
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


