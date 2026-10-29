#!/bin/bash
set -euxo pipefail 
if [ -f "${CUSTOM_INSTALL_DIR}/build/99-common.sh" ]; then source "${CUSTOM_INSTALL_DIR}/build/99-common.sh"; fi
if [ -f "./99-common.sh" ]; then source "./99-common.sh"; fi


# Read the packages yaml and install all repos
# You probably don't want to edit this file rather
# add a repo entry in your packages yaml.
#
# Which key holds the repositories depends on the base image:
#   - With Immutablue's backend library (IMMUTABLUE_HAVE_BACKENDS=1) it is the
#     backend's repo_key from backend.yaml (repo_urls on fedora-bootc), and each
#     repo is added with backend_repo_add, which knows where that OS keeps its
#     repositories. A backend with no repo_key (gnomeos, arch-bootc and
#     freebsd-be today) has nothing to add here.
#   - Without it (a base image from Immutablue master) it is always repo_urls,
#     and each entry is a .repo file curled into /etc/yum.repos.d as before.
repo_base=".immutablue.repo_urls"
if [[ "${IMMUTABLUE_HAVE_BACKENDS}" == "1" ]]
then
    repo_key="$(backend_get repo_key)"
    if [[ -z "${repo_key}" ]]
    then
        echo "Backend ${IMMUTABLUE_BACKEND} defines no repo_key; skipping repository setup"
        exit 0
    fi
    repo_base=".immutablue.${repo_key}"
fi


for yaml in ${PACKAGES_YAMLS}
do
    # Get repo names from base all
    repos=$(yq "${repo_base}.all[].name" < "${yaml}" 2>/dev/null || true)
    # Add version-specific repos
    if [[ -n "${VERSION}" ]]; then
        repos=$(printf '%s\n%s' "${repos}" "$(yq "${repo_base}.${VERSION}[].name" < "${yaml}" 2>/dev/null || true)")
    fi
    # Add architecture-specific repos
    repos=$(printf '%s\n%s' "${repos}" "$(yq "${repo_base}.all_${MARCH}[].name" < "${yaml}" 2>/dev/null || true)")
    # Add version + architecture-specific repos
    if [[ -n "${VERSION}" ]]; then
        repos=$(printf '%s\n%s' "${repos}" "$(yq "${repo_base}.${VERSION}_${MARCH}[].name" < "${yaml}" 2>/dev/null || true)")
    fi

    for repo in $repos
    do
        [[ -z "$repo" ]] && continue
        # Try to get URL from all
        url=$(yq "${repo_base}.all[] | select(.name == \"$repo\").url" < "${yaml}" 2>/dev/null || true)
        # Try version-specific if not found
        if [[ -z "$url" ]] && [[ -n "${VERSION}" ]]; then
            url=$(yq "${repo_base}.${VERSION}[] | select(.name == \"$repo\").url" < "${yaml}" 2>/dev/null || true)
        fi
        # Try architecture-specific if not found
        if [[ -z "$url" ]]; then
            url=$(yq "${repo_base}.all_${MARCH}[] | select(.name == \"$repo\").url" < "${yaml}" 2>/dev/null || true)
        fi
        # Try version + architecture if not found
        if [[ -z "$url" ]] && [[ -n "${VERSION}" ]]; then
            url=$(yq "${repo_base}.${VERSION}_${MARCH}[] | select(.name == \"$repo\").url" < "${yaml}" 2>/dev/null || true)
        fi

        if [[ -z "$url" ]]; then
            continue
        fi

        if [[ "${IMMUTABLUE_HAVE_BACKENDS}" == "1" ]]; then
            # A failed download stops the build: a missing repo means its
            # packages are missing from the image.
            backend_repo_add "$repo" "$url"
        else
            curl -Lo "/etc/yum.repos.d/$repo" "$url" || true
        fi
    done
done

