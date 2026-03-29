# To be filled out

REGISTRY := 
ifndef $(REGISTRY)
	# Example: registry.gitlab.com/<your-name>
	# Example: quay.io/<your-name>
	REGISTRY := change-me
endif
# Example: <your-project-name>'
IMAGE_BASE_TAG := change-me
IMAGE := $(REGISTRY)/$(IMAGE_BASE_TAG)
ALT_IMAGE := none

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

# Date tag for versioned snapshots (e.g., 43-20260129)
DATE_TAG := $(TAG)-$(shell date +%Y%m%d)

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
	check build push iso iso-config _iso_bootc _iso_classic \
	raw raw-config run_raw qcow2 qcow2-config run_qcow2 \
	ami ami-config gce gce-config vhd vhd-config \
	upgrade rebase clean


# Lint all shell scripts with shellcheck
# Exclusions match immutablue upstream:
#   SC1090/SC1091 - can't follow dynamic/non-constant source paths
#   SC2034       - variables used by sourced scripts appear unused
#   SC2046/SC2086 - intentional word splitting for package lists
#   SC2181       - inherited from template
check:
	shellcheck \
		-e SC1090,SC1091,SC2034,SC2046,SC2086,SC2181 \
		./post_install.sh \
		./build/*.sh


# No need to change
all: build push
all_upgrade: all update

# No need to change
install_targets := install_distrobox install_flatpak upgrade
install_or_update :$(install_targets)
install: install_or_update
update: install_or_update


# No need to change
build:
ifeq ($(SET_AS_LATEST), 1)
	buildah \
		build \
		--ignorefile ./.containerignore \
		--no-cache \
		-t $(IMAGE):latest \
		-t $(IMAGE):$(TAG) \
		-t $(IMAGE):$(DATE_TAG) \
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
		-t $(IMAGE):$(DATE_TAG) \
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
	buildah \
		push \
		$(IMAGE):$(DATE_TAG)
ifneq ($(ALT_IMAGE), none)
	buildah \
		tag \
		$(IMAGE):$(TAG) \
		$(ALT_IMAGE):$(TAG)
	buildah \
		push \
		$(ALT_IMAGE):$(TAG)
	buildah \
		tag \
		$(IMAGE):$(DATE_TAG) \
		$(ALT_IMAGE):$(DATE_TAG)
	buildah \
		push \
		$(ALT_IMAGE):$(DATE_TAG)
endif


retag:
	buildah tag $(IMAGE):$(TAG) $(IMAGE):$(RETAG) 


# Optional: flatpak refs for classic ISO builds
flatpak_refs/flatpaks: packages.yaml
	mkdir -p ./flatpak_refs
	bash -c 'source ./scripts/packages.sh && flatpak_make_refs'


# -----------------------------------
# bootc-image-builder targets
# -----------------------------------

# Shared bootc-image-builder container
BOOTC_IMAGE_BUILDER := quay.io/centos-bootc/bootc-image-builder:latest


# ISO Image Generation
# Default: Uses bootc-image-builder (same tooling as qcow2 generation)
# Classic: Use CLASSIC_ISO=1 for the legacy build-container-installer approach
#
# Usage:
#   make iso                    # Default: bootc-image-builder ISO
#   make CLASSIC_ISO=1 iso      # Classic: build-container-installer ISO
#
# Note: bootc-image-builder ISOs are "install-to-disk" installers.
#       Classic ISOs use Anaconda with more configuration options.
ifndef $(CLASSIC_ISO)
	CLASSIC_ISO := 0
endif

ISO_DIR := ./iso
ISO_BUILD_DIR := $(ISO_DIR)/.build-$(TAG)
ISO_CONFIG := $(ISO_DIR)/config-$(TAG).toml
ISO_OUTPUT := $(ISO_DIR)/$(IMAGE_BASE_TAG)-$(TAG).iso

iso:
ifeq ($(CLASSIC_ISO),1)
	@echo "Building classic ISO using build-container-installer..."
	$(MAKE) _iso_classic
else
	@echo "Building ISO using bootc-image-builder..."
	$(MAKE) _iso_bootc
endif

# Interactive ISO configuration generator
# Creates a config.toml with user credentials and optional SSH key
iso-config:
	@echo "=== ISO Configuration ==="
	@echo "Config file: $(ISO_CONFIG)"
	@echo ""
	@mkdir -p $(ISO_DIR)
	@echo "# ISO configuration" > $(ISO_CONFIG)
	@echo "# Generated by: make iso-config" >> $(ISO_CONFIG)
	@echo "" >> $(ISO_CONFIG)
	@read -p "Add a user account? [y/N]: " add_user; \
	if [ "$$add_user" = "y" ] || [ "$$add_user" = "Y" ]; then \
		read -p "Username [user]: " username; \
		username=$${username:-user}; \
		read -s -p "Password: " password; echo; \
		if [ -z "$$password" ]; then \
			echo "Error: Password cannot be empty."; \
			rm -f $(ISO_CONFIG); \
			exit 1; \
		fi; \
		read -p "Add to wheel group (sudo access)? [Y/n]: " add_wheel; \
		echo "" >> $(ISO_CONFIG); \
		echo "[[customizations.user]]" >> $(ISO_CONFIG); \
		echo "name = \"$$username\"" >> $(ISO_CONFIG); \
		echo "password = \"$$password\"" >> $(ISO_CONFIG); \
		if [ "$$add_wheel" != "n" ] && [ "$$add_wheel" != "N" ]; then \
			echo 'groups = ["wheel"]' >> $(ISO_CONFIG); \
		fi; \
		read -p "Add SSH public key? [y/N]: " add_ssh; \
		if [ "$$add_ssh" = "y" ] || [ "$$add_ssh" = "Y" ]; then \
			echo ""; \
			echo "Available SSH keys:"; \
			ls -1 ~/.ssh/*.pub 2>/dev/null || echo "  (none found in ~/.ssh/)"; \
			echo ""; \
			read -p "Path to SSH public key [~/.ssh/id_ed25519.pub]: " ssh_key_path; \
			ssh_key_path=$${ssh_key_path:-~/.ssh/id_ed25519.pub}; \
			ssh_key_path=$$(eval echo $$ssh_key_path); \
			if [ -f "$$ssh_key_path" ]; then \
				ssh_key=$$(cat "$$ssh_key_path"); \
				echo "key = \"$$ssh_key\"" >> $(ISO_CONFIG); \
				echo "Added SSH key from $$ssh_key_path"; \
			else \
				echo "Warning: SSH key not found at $$ssh_key_path, skipping."; \
			fi; \
		fi; \
		echo ""; \
		echo "User '$$username' configured."; \
	fi
	@echo ""
	@echo "Configuration saved to: $(ISO_CONFIG)"
	@echo "Run 'make iso' to build the ISO."

# bootc-image-builder ISO target (default)
_iso_bootc:
	@echo "Building bootc ISO for $(IMAGE):$(TAG)..."
	@mkdir -p $(ISO_BUILD_DIR)
	@if [ -f "$(ISO_CONFIG)" ]; then \
		echo "Using existing config: $(ISO_CONFIG)"; \
		cp $(ISO_CONFIG) $(ISO_BUILD_DIR)/config.toml; \
	else \
		echo "No user config found - enabling interactive first-boot setup"; \
		echo "# ISO config - interactive first-boot setup" > $(ISO_BUILD_DIR)/config.toml; \
		echo "" >> $(ISO_BUILD_DIR)/config.toml; \
		echo "[customizations.installer.kickstart]" >> $(ISO_BUILD_DIR)/config.toml; \
		echo 'contents = """' >> $(ISO_BUILD_DIR)/config.toml; \
		echo "firstboot --enable" >> $(ISO_BUILD_DIR)/config.toml; \
		echo '"""' >> $(ISO_BUILD_DIR)/config.toml; \
	fi
	sudo podman pull $(IMAGE):$(TAG)
	sudo podman run \
		--rm \
		-it \
		--privileged \
		--security-opt label=type:unconfined_t \
		-v $(ISO_BUILD_DIR):/output:z \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		-v $(ISO_BUILD_DIR)/config.toml:/config.toml:ro \
		$(BOOTC_IMAGE_BUILDER) \
		--type iso \
		--rootfs btrfs \
		--config /config.toml \
		$(IMAGE):$(TAG)
	sudo chown -R $$(id -u):$$(id -g) $(ISO_BUILD_DIR)
	mv $(ISO_BUILD_DIR)/bootiso/install.iso $(ISO_OUTPUT)
	rm -rf $(ISO_BUILD_DIR)
	sha256sum $(ISO_OUTPUT) > "$(ISO_OUTPUT).CHECKSUM"
	@echo ""
	@echo "ISO built: $(ISO_OUTPUT)"
	@if [ -f "$(ISO_CONFIG)" ]; then \
		echo "Configured with: $(ISO_CONFIG)"; \
	else \
		echo "First-boot setup enabled - user will configure account on first login"; \
	fi

# Classic ISO target (build-container-installer)
# Use with: make CLASSIC_ISO=1 iso
_iso_classic: flatpak_refs/flatpaks
	@echo "Building classic ISO for $(IMAGE):$(TAG)..."
	mkdir -p $(ISO_DIR)
	sudo podman run \
		--name $(IMAGE_BASE_TAG)-build \
		--rm \
		--privileged \
		--volume $(ISO_DIR):/build-container-installer/build \
		ghcr.io/jasonn3/build-container-installer:latest \
		VERSION=$(VERSION) \
		IMAGE_NAME=$(IMAGE_BASE_TAG) \
		IMAGE_TAG=$(TAG) \
		IMAGE_REPO=$(REGISTRY) \
		IMAGE_SIGNED=false \
		VARIANT=Silverblue \
		ISO_NAME="build/$(IMAGE_BASE_TAG)-$(TAG).iso"
	@echo ""
	@echo "Classic ISO built: $(ISO_OUTPUT)"

# Run ISO in QEMU for testing (containerized)
run_iso:
	@if [ ! -f "$(ISO_OUTPUT)" ]; then \
		echo "Error: No ISO found at $(ISO_OUTPUT). Run 'make iso' first."; \
		exit 1; \
	fi
	@echo "Booting ISO: $(ISO_OUTPUT)"
	@echo "Web console: http://localhost:8006"
	podman run --rm --cap-add NET_ADMIN \
		-p 127.0.0.1:8006:8006 \
		--env CPU_CORES=8 --env RAM_SIZE=8G --env DISK_SIZE=64G --env BOOT_MODE=uefi \
		--device=/dev/kvm \
		--device=/dev/net/tun \
		-v $(CURDIR)/$(ISO_OUTPUT):/boot.iso:Z \
		docker.io/qemux/qemu


# -----------------------------------
# Raw Disk Image Generation
# -----------------------------------
# Generates a raw disk image using bootc-image-builder
# Usage: make raw (after pushing the image to registry)
#        make raw-config (configure user accounts before building)
# Raw images are suitable for dd'ing to USB drives or using with cloud providers
RAW_DIR := ./raw
RAW_BUILD_DIR := $(RAW_DIR)/.build-$(TAG)
RAW_CONFIG := $(RAW_DIR)/config-$(TAG).toml
RAW_OUTPUT := $(RAW_DIR)/$(IMAGE_BASE_TAG)-$(TAG).img.zst

raw-config:
	@echo "=== Raw Image Configuration ==="
	@echo "Config file: $(RAW_CONFIG)"
	@echo ""
	@mkdir -p $(RAW_DIR)
	@echo "# Raw image configuration" > $(RAW_CONFIG)
	@echo "# Generated by: make raw-config" >> $(RAW_CONFIG)
	@echo "" >> $(RAW_CONFIG)
	@read -p "Add a user account? [y/N]: " add_user; \
	if [ "$$add_user" = "y" ] || [ "$$add_user" = "Y" ]; then \
		read -p "Username [user]: " username; \
		username=$${username:-user}; \
		read -s -p "Password: " password; echo; \
		if [ -z "$$password" ]; then \
			echo "Error: Password cannot be empty."; \
			rm -f $(RAW_CONFIG); \
			exit 1; \
		fi; \
		read -p "Add to wheel group (sudo access)? [Y/n]: " add_wheel; \
		echo "" >> $(RAW_CONFIG); \
		echo "[[customizations.user]]" >> $(RAW_CONFIG); \
		echo "name = \"$$username\"" >> $(RAW_CONFIG); \
		echo "password = \"$$password\"" >> $(RAW_CONFIG); \
		if [ "$$add_wheel" != "n" ] && [ "$$add_wheel" != "N" ]; then \
			echo 'groups = ["wheel"]' >> $(RAW_CONFIG); \
		fi; \
		read -p "Add SSH public key? [y/N]: " add_ssh; \
		if [ "$$add_ssh" = "y" ] || [ "$$add_ssh" = "Y" ]; then \
			echo ""; \
			echo "Available SSH keys:"; \
			ls -1 ~/.ssh/*.pub 2>/dev/null || echo "  (none found in ~/.ssh/)"; \
			echo ""; \
			read -p "Path to SSH public key [~/.ssh/id_ed25519.pub]: " ssh_key_path; \
			ssh_key_path=$${ssh_key_path:-~/.ssh/id_ed25519.pub}; \
			ssh_key_path=$$(eval echo $$ssh_key_path); \
			if [ -f "$$ssh_key_path" ]; then \
				ssh_key=$$(cat "$$ssh_key_path"); \
				echo "key = \"$$ssh_key\"" >> $(RAW_CONFIG); \
				echo "Added SSH key from $$ssh_key_path"; \
			else \
				echo "Warning: SSH key not found at $$ssh_key_path, skipping."; \
			fi; \
		fi; \
		echo ""; \
		echo "User '$$username' configured."; \
	fi
	@echo ""
	@echo "Configuration saved to: $(RAW_CONFIG)"
	@echo "Run 'make raw' to build the raw image."

raw:
	@echo "Building raw disk image for $(IMAGE):$(TAG)..."
	@mkdir -p $(RAW_BUILD_DIR)
	@if [ -f "$(RAW_CONFIG)" ]; then \
		echo "Using existing config: $(RAW_CONFIG)"; \
		cp $(RAW_CONFIG) $(RAW_BUILD_DIR)/config.toml; \
	else \
		echo "No user config found - creating minimal config"; \
		echo "Warning: Without a user configured, you may need console access"; \
		echo "# Raw image config - no users configured" > $(RAW_BUILD_DIR)/config.toml; \
	fi
	sudo podman pull $(IMAGE):$(TAG)
	sudo podman run \
		--rm \
		-it \
		--privileged \
		--security-opt label=type:unconfined_t \
		-v $(RAW_BUILD_DIR):/output:z \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		-v $(RAW_BUILD_DIR)/config.toml:/config.toml:ro \
		$(BOOTC_IMAGE_BUILDER) \
		--type raw \
		--rootfs btrfs \
		--config /config.toml \
		$(IMAGE):$(TAG)
	sudo chown -R $$(id -u):$$(id -g) $(RAW_BUILD_DIR)
	@echo "Compressing with zstd..."
	zstd -T4 -5 $(RAW_BUILD_DIR)/image/disk.raw -o $(RAW_OUTPUT)
	rm -rf $(RAW_BUILD_DIR)
	sha256sum $(RAW_OUTPUT) > "$(RAW_OUTPUT).CHECKSUM"
	@echo ""
	@echo "Raw image built: $(RAW_OUTPUT)"
	@echo "To extract: zstd -d $(RAW_OUTPUT) -o $(IMAGE_BASE_TAG)-$(TAG).img"

run_raw:
	@if [ ! -f "$(RAW_OUTPUT)" ]; then \
		echo "Error: No raw image found at $(RAW_OUTPUT). Run 'make raw' first."; \
		exit 1; \
	fi
	@echo "Extracting compressed image..."
	zstd -d $(RAW_OUTPUT) -o $(RAW_DIR)/.run-tmp.img -f
	@echo "Booting raw image: $(RAW_OUTPUT)"
	@echo "Web console: http://localhost:8006"
	podman run --rm --cap-add NET_ADMIN \
		-p 127.0.0.1:8006:8006 \
		--env CPU_CORES=8 --env RAM_SIZE=8G --env BOOT_MODE=uefi \
		--device=/dev/kvm \
		--device=/dev/net/tun \
		-v $(CURDIR)/$(RAW_DIR)/.run-tmp.img:/boot.img:Z \
		docker.io/qemux/qemu
	@rm -f $(RAW_DIR)/.run-tmp.img


# -----------------------------------
# QCOW2 Image Generation
# -----------------------------------
# Generates a qcow2 VM image using bootc-image-builder
# Usage: make qcow2 (after pushing the image to registry)
#        make qcow2-config (configure user accounts before building)
QCOW2_DIR := ./qcow2
QCOW2_BUILD_DIR := $(QCOW2_DIR)/.build-$(TAG)
QCOW2_CONFIG := $(QCOW2_DIR)/config-$(TAG).toml
QCOW2_OUTPUT := $(QCOW2_DIR)/$(IMAGE_BASE_TAG)-$(TAG).qcow2

qcow2-config:
	@echo "=== QCOW2 Image Configuration ==="
	@echo "Config file: $(QCOW2_CONFIG)"
	@echo ""
	@mkdir -p $(QCOW2_DIR)
	@echo "# QCOW2 image configuration" > $(QCOW2_CONFIG)
	@echo "# Generated by: make qcow2-config" >> $(QCOW2_CONFIG)
	@echo "" >> $(QCOW2_CONFIG)
	@read -p "Add a user account? [y/N]: " add_user; \
	if [ "$$add_user" = "y" ] || [ "$$add_user" = "Y" ]; then \
		read -p "Username [user]: " username; \
		username=$${username:-user}; \
		read -s -p "Password: " password; echo; \
		if [ -z "$$password" ]; then \
			echo "Error: Password cannot be empty."; \
			rm -f $(QCOW2_CONFIG); \
			exit 1; \
		fi; \
		read -p "Add to wheel group (sudo access)? [Y/n]: " add_wheel; \
		echo "" >> $(QCOW2_CONFIG); \
		echo "[[customizations.user]]" >> $(QCOW2_CONFIG); \
		echo "name = \"$$username\"" >> $(QCOW2_CONFIG); \
		echo "password = \"$$password\"" >> $(QCOW2_CONFIG); \
		if [ "$$add_wheel" != "n" ] && [ "$$add_wheel" != "N" ]; then \
			echo 'groups = ["wheel"]' >> $(QCOW2_CONFIG); \
		fi; \
		read -p "Add SSH public key? [y/N]: " add_ssh; \
		if [ "$$add_ssh" = "y" ] || [ "$$add_ssh" = "Y" ]; then \
			echo ""; \
			echo "Available SSH keys:"; \
			ls -1 ~/.ssh/*.pub 2>/dev/null || echo "  (none found in ~/.ssh/)"; \
			echo ""; \
			read -p "Path to SSH public key [~/.ssh/id_ed25519.pub]: " ssh_key_path; \
			ssh_key_path=$${ssh_key_path:-~/.ssh/id_ed25519.pub}; \
			ssh_key_path=$$(eval echo $$ssh_key_path); \
			if [ -f "$$ssh_key_path" ]; then \
				ssh_key=$$(cat "$$ssh_key_path"); \
				echo "key = \"$$ssh_key\"" >> $(QCOW2_CONFIG); \
				echo "Added SSH key from $$ssh_key_path"; \
			else \
				echo "Warning: SSH key not found at $$ssh_key_path, skipping."; \
			fi; \
		fi; \
		echo ""; \
		echo "User '$$username' configured."; \
	fi
	@echo ""
	@echo "Configuration saved to: $(QCOW2_CONFIG)"
	@echo "Run 'make qcow2' to build the qcow2 image."

qcow2:
	@echo "Building qcow2 VM image for $(IMAGE):$(TAG)..."
	@mkdir -p $(QCOW2_BUILD_DIR)
	@if [ -f "$(QCOW2_CONFIG)" ]; then \
		echo "Using existing config: $(QCOW2_CONFIG)"; \
		cp $(QCOW2_CONFIG) $(QCOW2_BUILD_DIR)/config.toml; \
	else \
		echo "No config found - creating minimal config"; \
		echo "# QCOW2 config - no users configured" > $(QCOW2_BUILD_DIR)/config.toml; \
	fi
	sudo podman pull $(IMAGE):$(TAG)
	sudo podman run \
		--rm \
		-it \
		--privileged \
		--security-opt label=type:unconfined_t \
		-v $(QCOW2_BUILD_DIR):/output:z \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		-v $(QCOW2_BUILD_DIR)/config.toml:/config.toml:ro \
		$(BOOTC_IMAGE_BUILDER) \
		--type qcow2 \
		--rootfs btrfs \
		--config /config.toml \
		$(IMAGE):$(TAG)
	sudo chown -R $$(id -u):$$(id -g) $(QCOW2_BUILD_DIR)
	mv $(QCOW2_BUILD_DIR)/qcow2/disk.qcow2 $(QCOW2_OUTPUT)
	rm -rf $(QCOW2_BUILD_DIR)
	sha256sum $(QCOW2_OUTPUT) > "$(QCOW2_OUTPUT).CHECKSUM"
	@echo ""
	@echo "QCOW2 image built: $(QCOW2_OUTPUT)"

run_qcow2:
	@if [ ! -f "$(QCOW2_OUTPUT)" ]; then \
		echo "Error: No qcow2 found at $(QCOW2_OUTPUT). Run 'make qcow2' first."; \
		exit 1; \
	fi
	@echo "Booting $(QCOW2_OUTPUT)..."
	@echo "SSH: ssh -p 2222 <user>@localhost"
	@echo "Exit: Ctrl-A X"
	sudo qemu-system-x86_64 \
		-enable-kvm \
		-m 4G \
		-smp 4 \
		-cpu host \
		-drive file=$(QCOW2_OUTPUT),format=qcow2 \
		-boot c \
		-nic user,hostfwd=tcp::2222-:22 \
		-nographic \
		-serial mon:stdio


# -----------------------------------
# AMI (Amazon Machine Image) Generation
# -----------------------------------
# Generates an AMI-compatible image using bootc-image-builder
# Usage: make ami (after pushing the image to registry)
#        make ami-config (configure user accounts before building)
AMI_DIR := ./ami
AMI_BUILD_DIR := $(AMI_DIR)/.build-$(TAG)
AMI_CONFIG := $(AMI_DIR)/config-$(TAG).toml
AMI_OUTPUT := $(AMI_DIR)/$(IMAGE_BASE_TAG)-$(TAG).ami.raw

ami-config:
	@echo "=== AMI Configuration ==="
	@echo "Config file: $(AMI_CONFIG)"
	@echo ""
	@mkdir -p $(AMI_DIR)
	@echo "# AMI configuration" > $(AMI_CONFIG)
	@echo "# Generated by: make ami-config" >> $(AMI_CONFIG)
	@echo "" >> $(AMI_CONFIG)
	@read -p "Add a user account? [y/N]: " add_user; \
	if [ "$$add_user" = "y" ] || [ "$$add_user" = "Y" ]; then \
		read -p "Username [user]: " username; \
		username=$${username:-user}; \
		read -s -p "Password: " password; echo; \
		if [ -z "$$password" ]; then \
			echo "Error: Password cannot be empty."; \
			rm -f $(AMI_CONFIG); \
			exit 1; \
		fi; \
		read -p "Add to wheel group (sudo access)? [Y/n]: " add_wheel; \
		echo "" >> $(AMI_CONFIG); \
		echo "[[customizations.user]]" >> $(AMI_CONFIG); \
		echo "name = \"$$username\"" >> $(AMI_CONFIG); \
		echo "password = \"$$password\"" >> $(AMI_CONFIG); \
		if [ "$$add_wheel" != "n" ] && [ "$$add_wheel" != "N" ]; then \
			echo 'groups = ["wheel"]' >> $(AMI_CONFIG); \
		fi; \
		read -p "Add SSH public key? [y/N]: " add_ssh; \
		if [ "$$add_ssh" = "y" ] || [ "$$add_ssh" = "Y" ]; then \
			echo ""; \
			echo "Available SSH keys:"; \
			ls -1 ~/.ssh/*.pub 2>/dev/null || echo "  (none found in ~/.ssh/)"; \
			echo ""; \
			read -p "Path to SSH public key [~/.ssh/id_ed25519.pub]: " ssh_key_path; \
			ssh_key_path=$${ssh_key_path:-~/.ssh/id_ed25519.pub}; \
			ssh_key_path=$$(eval echo $$ssh_key_path); \
			if [ -f "$$ssh_key_path" ]; then \
				ssh_key=$$(cat "$$ssh_key_path"); \
				echo "key = \"$$ssh_key\"" >> $(AMI_CONFIG); \
				echo "Added SSH key from $$ssh_key_path"; \
			else \
				echo "Warning: SSH key not found at $$ssh_key_path, skipping."; \
			fi; \
		fi; \
		echo ""; \
		echo "User '$$username' configured."; \
	fi
	@echo ""
	@echo "Configuration saved to: $(AMI_CONFIG)"
	@echo "Run 'make ami' to build the AMI."

ami:
	@echo "Building AMI for $(IMAGE):$(TAG)..."
	@mkdir -p $(AMI_BUILD_DIR)
	@if [ -f "$(AMI_CONFIG)" ]; then \
		echo "Using existing config: $(AMI_CONFIG)"; \
		cp $(AMI_CONFIG) $(AMI_BUILD_DIR)/config.toml; \
	else \
		echo "No user config found - creating minimal config"; \
		echo "# AMI config - no users configured" > $(AMI_BUILD_DIR)/config.toml; \
	fi
	sudo podman pull $(IMAGE):$(TAG)
	sudo podman run \
		--rm \
		-it \
		--privileged \
		--security-opt label=type:unconfined_t \
		-v $(AMI_BUILD_DIR):/output:z \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		-v $(AMI_BUILD_DIR)/config.toml:/config.toml:ro \
		$(BOOTC_IMAGE_BUILDER) \
		--type ami \
		--rootfs btrfs \
		--config /config.toml \
		$(IMAGE):$(TAG)
	sudo chown -R $$(id -u):$$(id -g) $(AMI_BUILD_DIR)
	mv $(AMI_BUILD_DIR)/image/disk.raw $(AMI_OUTPUT)
	rm -rf $(AMI_BUILD_DIR)
	sha256sum $(AMI_OUTPUT) > "$(AMI_OUTPUT).CHECKSUM"
	@echo ""
	@echo "AMI built: $(AMI_OUTPUT)"
	@echo "Upload to AWS with: aws ec2 import-image"


# -----------------------------------
# GCE (Google Compute Engine) Image Generation
# -----------------------------------
# Generates a GCE-compatible image using bootc-image-builder
# Output is a tar.gz file ready for upload to Google Cloud Storage
GCE_DIR := ./gce
GCE_BUILD_DIR := $(GCE_DIR)/.build-$(TAG)
GCE_CONFIG := $(GCE_DIR)/config-$(TAG).toml
GCE_OUTPUT := $(GCE_DIR)/$(IMAGE_BASE_TAG)-$(TAG).gce.tar.gz

gce-config:
	@echo "=== GCE Configuration ==="
	@echo "Config file: $(GCE_CONFIG)"
	@echo ""
	@mkdir -p $(GCE_DIR)
	@echo "# GCE configuration" > $(GCE_CONFIG)
	@echo "# Generated by: make gce-config" >> $(GCE_CONFIG)
	@echo "" >> $(GCE_CONFIG)
	@read -p "Add a user account? [y/N]: " add_user; \
	if [ "$$add_user" = "y" ] || [ "$$add_user" = "Y" ]; then \
		read -p "Username [user]: " username; \
		username=$${username:-user}; \
		read -s -p "Password: " password; echo; \
		if [ -z "$$password" ]; then \
			echo "Error: Password cannot be empty."; \
			rm -f $(GCE_CONFIG); \
			exit 1; \
		fi; \
		read -p "Add to wheel group (sudo access)? [Y/n]: " add_wheel; \
		echo "" >> $(GCE_CONFIG); \
		echo "[[customizations.user]]" >> $(GCE_CONFIG); \
		echo "name = \"$$username\"" >> $(GCE_CONFIG); \
		echo "password = \"$$password\"" >> $(GCE_CONFIG); \
		if [ "$$add_wheel" != "n" ] && [ "$$add_wheel" != "N" ]; then \
			echo 'groups = ["wheel"]' >> $(GCE_CONFIG); \
		fi; \
		read -p "Add SSH public key? [y/N]: " add_ssh; \
		if [ "$$add_ssh" = "y" ] || [ "$$add_ssh" = "Y" ]; then \
			echo ""; \
			echo "Available SSH keys:"; \
			ls -1 ~/.ssh/*.pub 2>/dev/null || echo "  (none found in ~/.ssh/)"; \
			echo ""; \
			read -p "Path to SSH public key [~/.ssh/id_ed25519.pub]: " ssh_key_path; \
			ssh_key_path=$${ssh_key_path:-~/.ssh/id_ed25519.pub}; \
			ssh_key_path=$$(eval echo $$ssh_key_path); \
			if [ -f "$$ssh_key_path" ]; then \
				ssh_key=$$(cat "$$ssh_key_path"); \
				echo "key = \"$$ssh_key\"" >> $(GCE_CONFIG); \
				echo "Added SSH key from $$ssh_key_path"; \
			else \
				echo "Warning: SSH key not found at $$ssh_key_path, skipping."; \
			fi; \
		fi; \
		echo ""; \
		echo "User '$$username' configured."; \
	fi
	@echo ""
	@echo "Configuration saved to: $(GCE_CONFIG)"
	@echo "Run 'make gce' to build the GCE image."

gce:
	@echo "Building GCE image for $(IMAGE):$(TAG)..."
	@mkdir -p $(GCE_BUILD_DIR)
	@if [ -f "$(GCE_CONFIG)" ]; then \
		echo "Using existing config: $(GCE_CONFIG)"; \
		cp $(GCE_CONFIG) $(GCE_BUILD_DIR)/config.toml; \
	else \
		echo "No user config found - creating minimal config"; \
		echo "# GCE config - no users configured" > $(GCE_BUILD_DIR)/config.toml; \
	fi
	sudo podman pull $(IMAGE):$(TAG)
	sudo podman run \
		--rm \
		-it \
		--privileged \
		--security-opt label=type:unconfined_t \
		-v $(GCE_BUILD_DIR):/output:z \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		-v $(GCE_BUILD_DIR)/config.toml:/config.toml:ro \
		$(BOOTC_IMAGE_BUILDER) \
		--type gce \
		--rootfs btrfs \
		--config /config.toml \
		$(IMAGE):$(TAG)
	sudo chown -R $$(id -u):$$(id -g) $(GCE_BUILD_DIR)
	mv $(GCE_BUILD_DIR)/image/disk.tar.gz $(GCE_OUTPUT)
	rm -rf $(GCE_BUILD_DIR)
	sha256sum $(GCE_OUTPUT) > "$(GCE_OUTPUT).CHECKSUM"
	@echo ""
	@echo "GCE image built: $(GCE_OUTPUT)"
	@echo "Upload to GCS with: gsutil cp $(GCE_OUTPUT) gs://your-bucket/"


# -----------------------------------
# VHD (Virtual Hard Disk) Image Generation
# -----------------------------------
# Generates a VHD image for Azure, Hyper-V, or Virtual PC
VHD_DIR := ./vhd
VHD_BUILD_DIR := $(VHD_DIR)/.build-$(TAG)
VHD_CONFIG := $(VHD_DIR)/config-$(TAG).toml
VHD_OUTPUT := $(VHD_DIR)/$(IMAGE_BASE_TAG)-$(TAG).vhd

vhd-config:
	@echo "=== VHD Configuration ==="
	@echo "Config file: $(VHD_CONFIG)"
	@echo ""
	@mkdir -p $(VHD_DIR)
	@echo "# VHD configuration" > $(VHD_CONFIG)
	@echo "# Generated by: make vhd-config" >> $(VHD_CONFIG)
	@echo "" >> $(VHD_CONFIG)
	@read -p "Add a user account? [y/N]: " add_user; \
	if [ "$$add_user" = "y" ] || [ "$$add_user" = "Y" ]; then \
		read -p "Username [user]: " username; \
		username=$${username:-user}; \
		read -s -p "Password: " password; echo; \
		if [ -z "$$password" ]; then \
			echo "Error: Password cannot be empty."; \
			rm -f $(VHD_CONFIG); \
			exit 1; \
		fi; \
		read -p "Add to wheel group (sudo access)? [Y/n]: " add_wheel; \
		echo "" >> $(VHD_CONFIG); \
		echo "[[customizations.user]]" >> $(VHD_CONFIG); \
		echo "name = \"$$username\"" >> $(VHD_CONFIG); \
		echo "password = \"$$password\"" >> $(VHD_CONFIG); \
		if [ "$$add_wheel" != "n" ] && [ "$$add_wheel" != "N" ]; then \
			echo 'groups = ["wheel"]' >> $(VHD_CONFIG); \
		fi; \
		read -p "Add SSH public key? [y/N]: " add_ssh; \
		if [ "$$add_ssh" = "y" ] || [ "$$add_ssh" = "Y" ]; then \
			echo ""; \
			echo "Available SSH keys:"; \
			ls -1 ~/.ssh/*.pub 2>/dev/null || echo "  (none found in ~/.ssh/)"; \
			echo ""; \
			read -p "Path to SSH public key [~/.ssh/id_ed25519.pub]: " ssh_key_path; \
			ssh_key_path=$${ssh_key_path:-~/.ssh/id_ed25519.pub}; \
			ssh_key_path=$$(eval echo $$ssh_key_path); \
			if [ -f "$$ssh_key_path" ]; then \
				ssh_key=$$(cat "$$ssh_key_path"); \
				echo "key = \"$$ssh_key\"" >> $(VHD_CONFIG); \
				echo "Added SSH key from $$ssh_key_path"; \
			else \
				echo "Warning: SSH key not found at $$ssh_key_path, skipping."; \
			fi; \
		fi; \
		echo ""; \
		echo "User '$$username' configured."; \
	fi
	@echo ""
	@echo "Configuration saved to: $(VHD_CONFIG)"
	@echo "Run 'make vhd' to build the VHD image."

vhd:
	@echo "Building VHD for $(IMAGE):$(TAG)..."
	@mkdir -p $(VHD_BUILD_DIR)
	@if [ -f "$(VHD_CONFIG)" ]; then \
		echo "Using existing config: $(VHD_CONFIG)"; \
		cp $(VHD_CONFIG) $(VHD_BUILD_DIR)/config.toml; \
	else \
		echo "No user config found - creating minimal config"; \
		echo "# VHD config - no users configured" > $(VHD_BUILD_DIR)/config.toml; \
	fi
	sudo podman pull $(IMAGE):$(TAG)
	sudo podman run \
		--rm \
		-it \
		--privileged \
		--security-opt label=type:unconfined_t \
		-v $(VHD_BUILD_DIR):/output:z \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		-v $(VHD_BUILD_DIR)/config.toml:/config.toml:ro \
		$(BOOTC_IMAGE_BUILDER) \
		--type vhd \
		--rootfs btrfs \
		--config /config.toml \
		$(IMAGE):$(TAG)
	sudo chown -R $$(id -u):$$(id -g) $(VHD_BUILD_DIR)
	mv $(VHD_BUILD_DIR)/image/disk.vhd $(VHD_OUTPUT)
	rm -rf $(VHD_BUILD_DIR)
	sha256sum $(VHD_OUTPUT) > "$(VHD_OUTPUT).CHECKSUM"
	@echo ""
	@echo "VHD built: $(VHD_OUTPUT)"
	@echo "Upload to Azure or use with Hyper-V"


# -----------------------------------



upgrade:
	sudo rpm-ostree update


rebase:
	sudo rpm-ostree rebase ostree-unverified-registry:$(IMAGE):$(TAG)

clean:
	rm -rf ./iso
	rm -rf ./raw
	rm -rf ./qcow2
	rm -rf ./ami
	rm -rf ./gce
	rm -rf ./vhd
	rm -rf ./flatpak_refs



