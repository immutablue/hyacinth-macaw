#!/bin/bash
set -euxo pipefail 
if [ -f "${CUSTOM_INSTALL_DIR}/build/99-common.sh" ]; then source "${CUSTOM_INSTALL_DIR}/build/99-common.sh"; fi
if [ -f "./99-common.sh" ]; then source "./99-common.sh"; fi


# Read the packages yaml and install all repos
# You probably don't want to edit this file rather
# add a repo entry in your packages yaml.
for yaml in ${PACKAGES_YAMLS}
do
    repos=$(cat <(yq '.immutablue.repo_urls[].name' < ${yaml}) <(yq ".immutablue.repo_urls_${MARCH}[].name" < ${yaml}))
    for repo in $repos
    do 
        curl -Lo "/etc/yum.repos.d/$repo" $(yq ".immutablue.repo_urls[] | select(.name == \"$repo\").url" < ${yaml}) || true
        curl -Lo "/etc/yum.repos.d/$repo" $(yq ".immutablue.repo_urls_${MARCH}[] | select(.name == \"$repo\").url" < ${yaml}) || true 
    done
    
    
done

