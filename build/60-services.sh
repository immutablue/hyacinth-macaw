#!/bin/bash
set -euxo pipefail 
if [ -f "${CUSTOM_INSTALL_DIR}/build/99-common.sh" ]; then source "${CUSTOM_INSTALL_DIR}/build/99-common.sh"; fi
if [ -f "./99-common.sh" ]; then source "./99-common.sh"; fi


# Modify systemd service settings for the system and 
# users.
#
# If you do need to modify this it might be due to 
# specific build versions and such
sys_unmask=$(get_immutablue_system_services_to_unmask)
sys_mask=$(get_immutablue_system_services_to_mask)
sys_disable=$(get_immutablue_system_services_to_disable)
sys_enable=$(get_immutablue_system_services_to_enable)
user_unmask=$(get_immutablue_user_services_to_unmask)
user_mask=$(get_immutablue_user_services_to_mask)
user_disable=$(get_immutablue_user_services_to_disable)
user_enable=$(get_immutablue_user_services_to_enable)


# Change one service's state.
#
# With Immutablue's backend library (see build/99-common.sh) this is the
# backend's backend_svc: systemctl on the systemd backends, sysrc(8) on
# freebsd-be, which has no masking and no per-user services and reports and
# skips those requests. Without it (a base image from Immutablue master) it is
# systemctl, called exactly as before.
#
# param $1: enable | disable | mask | unmask
# param $2: optional '--global' for the user-unit presets
# param $@: the unit
set_service_state() {
    local action="$1"
    shift

    if [[ "${IMMUTABLUE_HAVE_BACKENDS}" == "1" ]]
    then
        backend_svc "${action}" "$@"
    elif [[ "$1" == "--global" ]]
    then
        systemctl --global "${action}" "$2"
    else
        systemctl "${action}" "$1"
    fi
}


for svc in $sys_unmask
do 
    set_service_state unmask "$svc"
done

for svc in $sys_disable 
do 
    set_service_state disable "$svc"
done

for svc in $sys_enable 
do  
    set_service_state enable "$svc"
done 

for svc in $sys_mask 
do 
    set_service_state mask "$svc"
done


# Per user
for svc in $user_unmask
do 
    set_service_state unmask --global "$svc"
done

for svc in $user_disable 
do 
    set_service_state disable --global "$svc"
done

for svc in $user_enable 
do  
    set_service_state enable --global "$svc"
done 

for svc in $user_mask 
do 
    set_service_state mask --global "$svc"
done


