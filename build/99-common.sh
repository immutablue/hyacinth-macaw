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
        cat <(yq "$key[]" < "${yaml}") <(yq "${key}_${MARCH}[]" < "${yaml}")
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


