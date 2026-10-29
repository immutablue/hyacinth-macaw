+++
date = '2025-01-11T00:09:30-05:00'
draft = false
title = 'Immutablue Custom Build'
+++

# Immutablue Custom Build

You are using an Immutablue custom build. This was likely forked from the [project here](https://gitlab.com/immutablue/immutablue-custom).

Immutablue custom builds can pull either straight from the main Immutablue image (quay.io/immutablue/immutablue) and its derivatives:
- asahi (apple silicon support -- silverblue based only and does not support `lts` or `cyan`)
- kuberblue (kubernetes built image)
- trueblue (zfs focuses nas iamge)
- nucleus (stripped down image with no gui)
- kinoite (kde plasma based image)
- lazurite (lxqt based image)
- vauxite (xfce based image)

(others not currently supported):
- sericea (sway based image)
- onyx (budgie based image)
- cosmic (cosmic)
- bazzite (bazzite image w/ immutablue customizations)

as well there there are then "modifiers" to the above images which currently are (meaning you could do "lazurite" plus "cyan"):
- cyan (nvidia support) -- does not support `lts`
- lts (lts-kernel) -- does not support `cyan`

To use this, you simply pass in all-caps their name and `=1` in the make invocation like so:
```bash
make KINOITE=1 LTS=1 all
```
Your image will be built using upstream kinoite-lts, tagged appropriately, and pushed to your repo.

## Backends

Immutablue also builds on operating systems other than Fedora, and a custom build can sit on any of them:
- Fedora Atomic (`fedora-bootc`, the default): `make build`
- Arch Linux (`arch-bootc`): `make ARCHLINUX=1 build` (base `quay.io/immutablue/immutablue:arch`, `arch-nucleus` with `NUCLEUS=1`)
- FreeBSD 15.1 (`freebsd-be`): `make FREEBSD=1 build` on a FreeBSD host (base `quay.io/immutablue/immutablue:15.1-freebsd`, built from `Containerfile.freebsd`)

Packages can be listed once for every backend under `pkg` in the packages yaml (e.g. `- {name: fd-find, pacman: fd, freebsd: null}`), or per backend under `rpm`, `pacman` and `freebsd`. Update or switch images with `sudo immutablue-backend upgrade` and `sudo immutablue-backend rebase <image>:<tag>`, which work the same way on every backend. Custom builds on base images from before backends existed keep working as they always did. See `docs/backends.org` in the immutablue-custom repository for details.

## ZFS 

As of February 2025, all `lts` builds are guaranteed to have ZFS support. Non-`lts` builds are not guaranteed, but may have ZFS support

## Customizations
 
Typically you would fork (not clone!) the immutablue-custom repo itself and then make the customizations you would like in the various `build/` and `packages/` files and add any relevant post installation handling in `post_install.sh`

If you are not looking to do tremendous amount of customization a custom image may not be for you.

