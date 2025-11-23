#!/bin/bash
set -euxo pipefail 
if [ -f "${CUSTOM_INSTALL_DIR}/build/99-common.sh" ]; then source "${CUSTOM_INSTALL_DIR}/build/99-common.sh"; fi
if [ -f "./99-common.sh" ]; then source "./99-common.sh"; fi


# Read the packages yaml and install all repos
# You probably don't want to edit this file rather
# add a repo entry in your packages yaml.
for yaml in ${PACKAGES_YAMLS}
do
    # Get repo names from base all
    repos=$(yq '.immutablue.repo_urls.all[].name' < "${yaml}" 2>/dev/null || true)
    # Add version-specific repos
    if [[ -n "${VERSION}" ]]; then
        repos=$(printf '%s\n%s' "${repos}" "$(yq ".immutablue.repo_urls.${VERSION}[].name" < "${yaml}" 2>/dev/null || true)")
    fi
    # Add architecture-specific repos
    repos=$(printf '%s\n%s' "${repos}" "$(yq ".immutablue.repo_urls.all_${MARCH}[].name" < "${yaml}" 2>/dev/null || true)")
    # Add version + architecture-specific repos
    if [[ -n "${VERSION}" ]]; then
        repos=$(printf '%s\n%s' "${repos}" "$(yq ".immutablue.repo_urls.${VERSION}_${MARCH}[].name" < "${yaml}" 2>/dev/null || true)")
    fi

    for repo in $repos
    do
        [[ -z "$repo" ]] && continue
        # Try to get URL from all
        url=$(yq ".immutablue.repo_urls.all[] | select(.name == \"$repo\").url" < "${yaml}" 2>/dev/null || true)
        # Try version-specific if not found
        if [[ -z "$url" ]] && [[ -n "${VERSION}" ]]; then
            url=$(yq ".immutablue.repo_urls.${VERSION}[] | select(.name == \"$repo\").url" < "${yaml}" 2>/dev/null || true)
        fi
        # Try architecture-specific if not found
        if [[ -z "$url" ]]; then
            url=$(yq ".immutablue.repo_urls.all_${MARCH}[] | select(.name == \"$repo\").url" < "${yaml}" 2>/dev/null || true)
        fi
        # Try version + architecture if not found
        if [[ -z "$url" ]] && [[ -n "${VERSION}" ]]; then
            url=$(yq ".immutablue.repo_urls.${VERSION}_${MARCH}[] | select(.name == \"$repo\").url" < "${yaml}" 2>/dev/null || true)
        fi

        if [[ -n "$url" ]]; then
            curl -Lo "/etc/yum.repos.d/$repo" "$url" || true
        fi
    done
done

