#!/bin/bash
set -euxo pipefail 
if [ -f "${CUSTOM_INSTALL_DIR}/build/99-common.sh" ]; then source "${CUSTOM_INSTALL_DIR}/build/99-common.sh"; fi
if [ -f "./99-common.sh" ]; then source "./99-common.sh"; fi


# Removes files listed in your packages yaml
# You likely will not need to edit this but
# it might make more sense for complex file 
# removal / change operations.
files=$(get_immutablue_files_to_remove)


if [[ "$files" != "" ]]
then 
    for file in $files
    do  
        rm -rfv "$file" 
    done 
fi

