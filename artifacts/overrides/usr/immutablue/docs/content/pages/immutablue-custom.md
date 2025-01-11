+++
date = '2025-01-11T00:09:30-05:00'
draft = false
title = 'Immutablue Custom Build'
+++

# Immutablue Custom Build

You are using an Immutablue custom build. This was likely forked from the [project here](https://gitlab.com/immutablue/immutablue-custom).

Immutablue custom builds can pull either straight from the main Immutablue image (quay.io/immutablue/immutablue) or it can pull from any number of intermediate layers:
- asahi
- cyan
- kuberblue
- trueblue
- nucleus

You can also mix and match these via the various build files. For example, in your custom build if you would like to build a cutom image that relies upon both Kuberblue and Nucleus:
```bash
make KUBERBLUE_NUCLEUS=1 all
```
Your image will be built, tagged appropriately, and pushed. 

This also works for rebasing. If you want to rebase without having to figure out what the tag is:
```bash
make KUBERBLUE_NUCLEUS=1 rebase
```

## Customizations
 
Typically you would fork (not clone!) the immutablue-custom repo itself and then make the customizations you would like in the various `build/` and `packages/` files and add any relevant post installation handling in `post_install.sh`

If you are not looking to do tremendous amount of customization a custom image may not be for you.

