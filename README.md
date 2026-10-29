# Immutablue Custom

A forkable repo that you can use to create a custom build of [Immutablue](https://gitlab.com/immutablue/immutablue)


## Getting started

The default base is Immutablue 44. Use `make VERSION=43 build` to target another release, or pass `--build-arg FEDORA_VERSION=43` when building the Containerfile directly. Set the registry and project name below before building or pushing your image.

- Fork this repo to your git provider of choice.
- Find `change-me` in `Makefile` and `Containerfile` and update them using your container registry and project name of choice (probably from your git provider but doesn't have to be).
- Have a look at `packages/packages.custom-50-hyacinth-macaw.yaml` (this image's packages) and `packages/template.packages.custom-00-template.yaml` (every key, documented). Copy the latter to a new file, or make tweaks to the former.
    - The syntax overall should be straight forward, there are comments that are should describe things and what they do.
    - If there are questions open an issue.
- Add anything you want into `post_install.sh` for your customization. Such as pulling in your dotfiles for your user, cloning repos, etc. For an example of what could be done, check out how this is done in [Hyacinth Macaw](https://gitlab.com/immutablue/hyacinth-macaw/-/blob/master/post_install.sh?ref_type=heads). There really is endless possibilities of what you can do.
    - When writing your `post_install.sh` it is best to write it in a way that it can handle being ran multiple times in a row without negative effects (its ran on every update).
- Run `make all` and follow rebasing below
    - If you are using nvidia, you can make use of `Immutablue Cyan` by simply passing `CYAN=1` in your `make` command: `make CYAN=1 build`


## Backends (Fedora, Arch Linux, FreeBSD)
Immutablue builds on more than one operating system, called a *backend*. Your custom image is a layer on top of an Immutablue image and uses whatever backend that image was built on:

| Flag | Backend | Base image | Your tag |
|------|---------|------------|----------|
| (none) | `fedora-bootc` | `quay.io/immutablue/immutablue:44` | `44` |
| `NUCLEUS=1` | `fedora-bootc` | `quay.io/immutablue/immutablue:44-nucleus` | `44-nucleus` |
| `ARCHLINUX=1` | `arch-bootc` | `quay.io/immutablue/immutablue:arch` | `arch` |
| `ARCHLINUX=1 NUCLEUS=1` | `arch-bootc` | `quay.io/immutablue/immutablue:arch-nucleus` | `arch-nucleus` |
| `FREEBSD=1` | `freebsd-be` | `quay.io/immutablue/immutablue:15.1-freebsd` | `15.1-freebsd` |
| `FREEBSD=1 NUCLEUS=1` | `freebsd-be` | `quay.io/immutablue/immutablue:15.1-freebsd-nucleus` | `15.1-freebsd-nucleus` |

- The scripts in `build/` detect the backend library the base image ships in `/usr/immutablue` and install packages, add repos and set services through it (dnf5, pacman or pkg; systemctl or sysrc).
- Packages can be named once for every backend with the logical `pkg` lists, and per backend with the native `rpm`, `pacman` and `freebsd` lists:
```yaml
immutablue:
  pkg:
    all:
    - tmux                                          # same name everywhere
    - {name: fd-find, pacman: fd, freebsd: null}    # renamed on Arch, skipped on FreeBSD
  pacman:
    all:
    - pacman-contrib                                # Arch only
  services_enable_sys:
    all:
    - {name: sshd.service, rc: sshd}                # sshd_enable=YES on FreeBSD
```
- **FreeBSD** images use `Containerfile.freebsd` and must be built on a FreeBSD 15.1 host (podman-suite + ocijail) with `gmake FREEBSD=1 build`; the build is squashed (`--squash`) so the copied build context does not stay in the image. From Linux, use Immutablue's builder VM (`backends/freebsd-be/builder-vm.sh` in the [immutablue](https://gitlab.com/immutablue/immutablue) repo).
- **Older base images**: Immutablue images built from Immutablue master have no backend library. On those the build behaves exactly as it always did (`rpm-ostree`, `systemctl`, only the `rpm*` keys), so this repo still builds on them.
- The ISO/disk image targets (`iso`, `qcow2`, `raw`, ...) use bootc-image-builder and only support the Fedora backend.
- Details, the full key reference and how to test the backend path on a host: [docs/backends.org](docs/backends.org).


## Rebasing
- Rebase an [Immutablue](https://gitlab.com/immutablue/immutablue) instance to your build with `make rebase` from your repo (pass the same flags you built with, e.g. `make ARCHLINUX=1 rebase`).
    - On Immutablue images with backends this runs `sudo immutablue-backend rebase <image>:<tag>`, which works on every backend; on older images it runs `rpm-ostree rebase`.
- After first boot be sure to run `immmutablue install`


## Updating 
- `immutablue update`


## FAQs
- Help, I broke a distrobox container. How do I fix it?
    - The beautiful thing about having things declared as code is you can just nuke it and remake it: `distrobox rm -f <name>` then follow up with `immutablue update`
- How do I get started 
    - Have a look at the source and the comments for the files here
- I forked this repo, but you made changes how can I get them?
    - Set up an upstream origin in git: 
```
git remote add upstream https://gitlab.com/immutablue/immutablue-custom.git
git fetch upstream 
git <merge_or_rebase> upstream/master
```
