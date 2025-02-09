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

## ZFS 

As of February 2025, all `lts` builds are guaranteed to have ZFS support. Non-`lts` builds are not guaranteed, but may have ZFS support

## Customizations
 
Typically you would fork (not clone!) the immutablue-custom repo itself and then make the customizations you would like in the various `build/` and `packages/` files and add any relevant post installation handling in `post_install.sh`

If you are not looking to do tremendous amount of customization a custom image may not be for you.

