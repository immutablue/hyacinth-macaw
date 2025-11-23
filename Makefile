# To be filled out

REGISTRY := 
ifndef $(REGISTRY)
	REGISTRY := quay.io/immutablue
endif

IMAGE_BASE_TAG := hyacinth-macaw
IMAGE := $(REGISTRY)/$(IMAGE_BASE_TAG)
ALT_IMAGE := none

# This is based on asahi? This is only 
# relevant for m-series macs!
ifndef $(ASAHI)
	ASAHI := 0
endif

# This forms something similar to:
# registry.gitlab.com/<your-name>/<your-project>
# and represents where the image will be pushed to
IMAGE := $(REGISTRY)/$(IMAGE_BASE_TAG)


# Current version to be based off of
# Change this after major releases
CURRENT := 43

# Can override in make
ifndef $(VERSION)
	VERSION = $(CURRENT)
endif

# Can override in make
ifndef $(TAG)
	TAG = $(VERSION)
endif


BASE_IMAGE := quay.io/immutablue/immutablue:$(VERSION)

# -----------------------------------

# No desktop environment
ifeq ($(NUCLEUS),1)
	BASE_IMAGE := quay.io/immutablue/immutablue:$(VERSION)-nucleus
	TAG := $(TAG)-nucleus
endif

# KDE desktop
ifeq ($(KINOITE),1)
	BASE_IMAGE := quay.io/immutablue/immutablue:$(VERSION)-kinoite
	TAG := $(TAG)-kinoite
endif

# Sway desktop
ifeq ($(SERICEA),1)
	BASE_IMAGE := quay.io/immutablue/immutablue:$(VERSION)-sericea
	TAG := $(TAG)-sericea
endif

# Budgie desktop
ifeq ($(ONYX),1)
	BASE_IMAGE := quay.io/immutablue/immutablue:$(VERSION)-onyx
	TAG := $(TAG)-kinoite
endif

# XFCE desktop
ifeq ($(VAUXITE),1)
	BASE_IMAGE := quay.io/immutablue/immutablue:$(VERSION)-vauxite
	TAG := $(TAG)-vauxite
endif

# LXQt desktop
ifeq ($(LAZURITE),1)
	BASE_IMAGE := quay.io/immutablue/immutablue:$(VERSION)-lazurite
	TAG := $(TAG)-lazurite
endif

# Cosmic desktop
ifeq ($(COSMIC),1)
	BASE_IMAGE := quay.io/immutablue/immutablue:$(VERSION)-cosmic
	TAG := $(TAG)-cosmic
endif

# Not supported yet
# Bazzite base w/ immutablue addons
ifeq ($(BAZZITE),1)
	BASE_IMAGE := quay.io/immutablue/immutablue:$(VERSION)-nucleus
	TAG := $(TAG)-bazzite
endif


ifeq ($(KUBERBLUE),1)
	BASE_IMAGE := quay.io/immutablue/kuberblue:$(VERSION)
	TAG := $(TAG)-kuberblue
endif

ifeq ($(TRUEBLUE),1)
	BASE_IMAGE := quay.io/immutablue/trueblue:$(VERSION)
	TAG := $(TAG)-trueblue
endif



# Build-time customizations from build options
ifeq ($(ASAHI),1)
	BASE_IMAGE := quay.io/immutablue/immutablue:$(VERSION)-asahi
	TAG := $(TAG)-asahi
endif

ifeq ($(CYAN),1)
	BASE_IMAGE := $(BASE_IMAGE)-cyan
	TAG := $(TAG)-cyan
endif


ifeq ($(LTS), 1)
	BASE_IMAGE := $(BASE_IMAGE)-lts
	TAG := $(TAG)-lts
endif

ifeq ($(NIX), 1)
	BASE_IMAGE := $(BASE_IMAGE)-nix
	TAG := $(TAG)-nix
endif


# -----------------------------------


# If you want to set this as latest as well
# set this to 1 in your call to make
ifndef $(SET_AS_LATEST)
	SET_AS_LATEST = 0
endif
	

# No need to change
FULL_TAG := $(IMAGE):$(TAG)

# No need to change
.PHONY: all all_upgrade install update install_or_update \
	build push iso upgrade rebase clean check


# No need to change
all: build push
all_upgrade: all update

# No need to change
install_targets := install_distrobox install_flatpak upgrade
install_or_update :$(install_targets)
install: install_or_update
update: install_or_update


check:
	shellcheck \
		-e SC2181 \
		./post_install.sh

# No need to change
build: check
ifeq ($(SET_AS_LATEST), 1)
	buildah \
		build \
		--ignorefile ./.containerignore \
		--no-cache \
		-t $(IMAGE):latest \
		-t $(IMAGE):$(TAG) \
		-f ./Containerfile \
		--build-arg=BASE_IMAGE=$(BASE_IMAGE) \
		--build-arg=IMMUTABLUE_BASE=$(IMMUTABLUE_BASE) \
		--build-arg=IMAGE_TAG=$(IMAGE_BASE_TAG):$(TAG) \
		--build-arg=FEDORA_VERSION=$(VERSION)
else
	buildah \
		build \
		--ignorefile ./.containerignore \
		--no-cache \
		-t $(IMAGE):$(TAG) \
		-f ./Containerfile \
		--build-arg=BASE_IMAGE=$(BASE_IMAGE) \
		--build-arg=IMMUTABLUE_BASE=$(IMMUTABLUE_BASE) \
		--build-arg=IMAGE_TAG=$(IMAGE_BASE_TAG):$(TAG) \
		--build-arg=FEDORA_VERSION=$(VERSION)
endif
		

# No need to change
push:
ifeq ($(SET_AS_LATEST), 1)
	buildah \
		push \
		$(IMAGE):latest
endif
	buildah \
		push \
		$(IMAGE):$(TAG)
ifneq ($(ALT_IMAGE), none)
	buildah \
		tag \
		$(IMAGE):$(TAG) \
		$(ALT_IMAGE):$(TAG)
	buildah \
		push \
		$(ALT_IMAGE):$(TAG)
endif


retag:
	buildah tag $(IMAGE):$(TAG) $(IMAGE):$(RETAG) 


# TODO: Be implemented correctly
flatpak_refs/flatpaks: packages.yaml
	mkdir -p ./flatpak_refs
	bash -c 'source ./scripts/packages.sh && flatpak_make_refs'


# TODO: Be implemented correctly
iso: #flatpak_refs/flatpaks
	mkdir -p ./iso
	sudo podman run \
		--name immutablue-build \
		--rm \
		--privileged \
		--volume ./iso:/build-container-installer/build \
		ghcr.io/jasonn3/build-container-installer:latest \
		VERSION=$(VERSION) \
		IMAGE_NAME=$(IMAGE_BASE_TAG) \
		IMAGE_TAG=$(TAG) \
		IMAGE_REPO=$(REGISTRY) \
		IMAGE_SIGNED=false \
		VARIANT=Silverblue \
		ISO_NAME="build/immutablue-hyacinth-macaw-$(TAG).iso"
	# sudo podman run \
	# 	--name immutablue-build \
	# 	--rm \
	# 	--privileged \
	# 	--volume ./iso:/build-container-installer/build \
	# 	--volume ./flatpak_refs:/build-container-installer/flatpak_refs \
	# 	ghcr.io/jasonn3/build-container-installer:latest \
	# 	VERSION=$(VERSION) \
	# 	IMAGE_NAME=$(IMAGE_BASE_TAG) \
	# 	IMAGE_TAG=$(TAG) \
	# 	IMAGE_REPO=$(REGISTRY) \
	# 	IMAGE_SIGNED=false \
	# 	FLATPAK_REMOTE_NAME=flathub \
	# 	FLATPAK_REMOTE_URL=https://flathub.org/repo/flathub.flatpakrepo \
	# 	FLATPAK_REMOTE_REFS_DIR=/build-container-installer/flatpak_refs \
	# 	VARIANT=Silverblue \
	# 	ISO_NAME="build/immutablue-$(TAG).iso"


# You probably don't want to push this anywhere
# push_iso:
# 	s3cmd \
# 		--access_key=$(S3_ACCESS_KEY) \
# 		--secret_key=$(S3_SECRET_KEY) \
# 		--host=us-east-1.linodeobjects.com \
# 		--host-bucket='%(bucket)s.us-east-1.linodeobjects.com' \
# 		put ./iso/immutablue-$(TAG).iso s3://immutablue/immutablue-$(TAG).iso
# 	
# 	s3cmd \
# 		--access_key=$(S3_ACCESS_KEY) \
# 		--secret_key=$(S3_SECRET_KEY) \
# 		--host=us-east-1.linodeobjects.com \
# 		--host-bucket='%(bucket)s.us-east-1.linodeobjects.com' \
# 		put ./iso/immutablue-$(TAG).iso-CHECKSUM s3://immutablue/immutablue-$(TAG).iso-CHECKSUM



upgrade:
	sudo rpm-ostree update


rebase:
	sudo rpm-ostree rebase ostree-unverified-registry:$(IMAGE):$(TAG)

clean:
	rm -rf ./iso
	rm -rf ./flatpak_refs


