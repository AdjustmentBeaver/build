################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
override COMPILE_NS_USER   := 64
override COMPILE_NS_KERNEL := 64
override COMPILE_S_USER    := 64
override COMPILE_S_KERNEL  := 64

include common.mk

################################################################################
# Paths to git projects and various binaries
################################################################################
ARM_TF_PATH		?= $(ROOT)/arm-trusted-firmware
ARM_TF_OUT		?= $(ARM_TF_PATH)/build/rpi3/debug
ARM_TF_BIN		?= $(ARM_TF_OUT)/bl31.bin
ARM_TF_TMP		?= $(ARM_TF_OUT)/bl31.tmp
ARM_TF_HEAD		?= $(ARM_TF_OUT)/bl31.head
ARM_TF_BOOT		?= $(ARM_TF_OUT)/optee.bin

U-BOOT_PATH			?= $(ROOT)/u-boot
U-BOOT_BIN			?= $(U-BOOT_PATH)/u-boot.bin
U-BOOT_RPI_BIN	?= $(U-BOOT_PATH)/u-boot-rpi.bin

RPI3_FIRMWARE_PATH			?= $(BUILD_PATH)/rpi3/firmware
RPI3_HEAD_BIN						?= $(ROOT)/out/head.bin
RPI3_BOOT_CONFIG				?= $(RPI3_FIRMWARE_PATH)/config.txt
RPI3_UBOOT_ENV					?= $(ROOT)/out/uboot.env
RPI3_UBOOT_ENV_TXT			?= $(RPI3_FIRMWARE_PATH)/uboot.env.txt
RPI3_STOCK_FW_PATH			?= $(ROOT)/firmware
RPI3_STOCK_FW_PATH_BOOT	?= $(RPI3_STOCK_FW_PATH)/boot
OPTEE_OS_PAGER					?= $(OPTEE_OS_PATH)/out/arm/core/tee-pager.bin

LINUX_IMAGE			?= $(LINUX_PATH)/arch/arm64/boot/Image
LINUX_DTB				?= $(LINUX_PATH)/arch/arm64/boot/dts/broadcom/bcm2710-rpi-3-b.dtb
MODULE_OUTPUT		?= $(ROOT)/module_output
FIT_IMAGE				?= $(ROOT)/out/fit/image.fit

BOOT_TARGET		?= $(ROOT)/out/boot
BOOT_FS_FILE	?= $(ROOT)/out/boot.tar.gz

PUBKEY_DTB	?= rpi3_pubkey.dtb

################################################################################
# Targets
################################################################################
ifeq ($(CFG_TEE_BENCHMARK),y)
all: benchmark-app
clean: benchmark-app-clean
endif
all: arm-tf optee-os optee-client xtest u-boot u-boot-rpi-bin\
	linux gen-pubkey u-boot-fit update_rootfs optee-examples archive-boot
clean: arm-tf-clean busybox-clean u-boot-clean u-boot-rpi-bin-clean \
	optee-os-clean optee-client-clean head-bin-clean \
	optee-examples-clean gen-pubkey-clean u-boot-fit-clean \
	archive-boot-clean u-boot-env-clean linux-clean xtest-clean \

include toolchain.mk

################################################################################
# ARM Trusted Firmware
################################################################################
ARM_TF_EXPORTS ?= \
	CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

ARM_TF_FLAGS ?= \
	BL32=$(OPTEE_OS_BIN) \
	DEBUG=1 \
	V=0 \
	CRASH_REPORTING=1 \
	LOG_LEVEL=40 \
	PLAT=rpi3 \
	SPD=opteed

arm-tf: optee-os
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ARM_TF_PATH) $(ARM_TF_FLAGS) all
	cd $(ARM_TF_OUT) && \
	  dd if=/dev/zero of=scratch bs=1c count=131072 && \
	  cat $(ARM_TF_BIN) scratch > $(ARM_TF_TMP) && \
	  dd if=$(ARM_TF_TMP) of=$(ARM_TF_HEAD) bs=1c count=131072 && \
	  cat $(ARM_TF_HEAD) $(OPTEE_OS_PAGER) > $(ARM_TF_BOOT) && \
	  rm scratch $(ARM_TF_TMP) $(ARM_TF_HEAD)

arm-tf-clean:
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ARM_TF_PATH) $(ARM_TF_FLAGS) clean

################################################################################
# Das U-Boot
################################################################################

U-BOOT_DEFAULT_EXPORTS ?= CROSS_COMPILE=$(LEGACY_AARCH64_CROSS_COMPILE) ARCH=arm64
U-BOOT_EXPORTS ?= $(U-BOOT_DEFAULT_EXPORTS) EXT_DTB=$(ROOT)/out/fit/$(PUBKEY_DTB)

.PHONY: u-boot-tools
u-boot-tools: $(RPI3_HEAD_BIN)
	$(U-BOOT_DEFAULT_EXPORTS) EXT_DTB=$(RPI3_STOCK_FW_PATH_BOOT)/bcm2710-rpi-3-b.dtb $(MAKE) -C $(U-BOOT_PATH) tools

.PHONY: u-boot
u-boot: u-boot-tools
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) rpi_3_defconfig
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) all

u-boot-clean:
	$(U-BOOT_DEFAULT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) clean

u-boot-rpi-bin: $(RPI3_UBOOT_ENV) u-boot
	cd $(U-BOOT_PATH) && cat $(RPI3_HEAD_BIN) $(U-BOOT_BIN) > $(U-BOOT_RPI_BIN)

u-boot-rpi-bin-clean:
	rm -f $(U-BOOT_RPI_BIN)

$(RPI3_HEAD_BIN): $(RPI3_FIRMWARE_PATH)/head.S
	mkdir -p $(ROOT)/out/
	$(AARCH64_CROSS_COMPILE)as $< -o $(ROOT)/out/head.o
	$(AARCH64_CROSS_COMPILE)objcopy -O binary $(ROOT)/out/head.o $@

head-bin-clean:
	rm -f $(RPI3_HEAD_BIN) $(ROOT)/out/head.o

$(RPI3_UBOOT_ENV): $(RPI3_UBOOT_ENV_TXT) u-boot
	mkdir -p $(ROOT)/out
	$(U-BOOT_PATH)/tools/mkenvimage -s 0x4000 -o $(ROOT)/out/uboot.env $(RPI3_UBOOT_ENV_TXT)

u-boot-env-clean:
	rm -f $(RPI3_UBOOT_ENV)

gen-pubkey:
	@test -s dev.key && mkdir -p $(ROOT)/out/keys && cd $(ROOT)/out/keys && \
		openssl genrsa -F4 -out dev.key 2048 && \
		dev.crt && openssl req -batch -new -x509 -key dev.key -out dev.crt || \
		echo "Key has already been generated"

gen-pubkey-clean:
		rm -rf $(ROOT)/out/keys

.PHONY: u-boot-fit
u-boot-fit: u-boot-tools linux arm-tf
	mkdir -p $(ROOT)/out/fit
	cd $(ROOT)/out/fit && ln -sf $(LINUX_IMAGE) && ln -sf $(ARM_TF_BOOT) && ln -sf $(LINUX_DTB) && ln -sf $(RPI3_FIRMWARE_PATH)/rpi3_fit.its && cp $(LINUX_DTB) rpi3_pubkey.dtb
	cd $(ROOT)/out/fit && $(U-BOOT_PATH)/tools/mkimage -f rpi3_fit.its -K rpi3_pubkey.dtb -k keys -r image.fit

u-boot-fit-clean:
	rm -rf $(ROOT)/out/fit

################################################################################
# Busybox
################################################################################
BUSYBOX_COMMON_TARGET = rpi3
BUSYBOX_CLEAN_COMMON_TARGET = rpi3 clean

busybox: busybox-common

busybox-clean: busybox-clean-common

busybox-cleaner: busybox-cleaner-common
################################################################################
# Linux kernel
################################################################################
LINUX_DEFCONFIG_COMMON_ARCH := arm64
LINUX_DEFCONFIG_COMMON_FILES := \
	$(LINUX_PATH)/arch/arm64/configs/bcmrpi3_defconfig \
	$(CURDIR)/kconfigs/rpi3.conf

linux-defconfig: $(LINUX_PATH)/.config

LINUX_COMMON_FLAGS += ARCH=arm64

linux: linux-common
	$(MAKE) -C $(LINUX_PATH) $(LINUX_COMMON_FLAGS) INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=$(MODULE_OUTPUT) modules_install

linux-defconfig-clean: linux-defconfig-clean-common

LINUX_CLEAN_COMMON_FLAGS += ARCH=arm64

linux-clean: linux-clean-common

LINUX_CLEANER_COMMON_FLAGS += ARCH=arm64

linux-cleaner: linux-cleaner-common

################################################################################
# OP-TEE
################################################################################
OPTEE_OS_COMMON_FLAGS += PLATFORM=rpi3
optee-os: optee-os-common

OPTEE_OS_CLEAN_COMMON_FLAGS += PLATFORM=rpi3
optee-os-clean: optee-os-clean-common

optee-client: optee-client-common

optee-client-clean: optee-client-clean-common

################################################################################
# xtest / optee_test
################################################################################
xtest: xtest-common

xtest-clean: xtest-clean-common

xtest-patch: xtest-patch-common

################################################################################
# Sample applications / optee_examples
################################################################################
optee-examples: optee-examples-common

optee-examples-clean: optee-examples-clean-common

################################################################################
# benchmark
################################################################################
benchmark-app: benchmark-app-common

benchmark-app-clean: benchmark-app-clean-common

################################################################################
# Root FS
################################################################################
.PHONY: filelist-tee
filelist-tee: linux
filelist-tee: filelist-tee-common
	@echo "dir /usr/bin 755 0 0" >> $(GEN_ROOTFS_FILELIST)
	@cd $(MODULE_OUTPUT) && find ! -path . -type d | sed 's/\.\(.*\)/dir \1 755 0 0/g' >> $(GEN_ROOTFS_FILELIST)
	@cd $(MODULE_OUTPUT) && find -type f | sed "s|\.\(.*\)|file \1 $(MODULE_OUTPUT)\1 755 0 0|g" >> $(GEN_ROOTFS_FILELIST)

.PHONY: archive-boot
archive-boot: u-boot-fit
	mkdir -p $(BOOT_TARGET)
	cd $(BOOT_TARGET) && \
		ln -sf $(RPI3_BOOT_CONFIG) && \
		ln -sf $(FIT_IMAGE) && \
		ln -sf $(RPI3_UBOOT_ENV) && \
		ln -sf $(U-BOOT_RPI_BIN) && \
		ln -sf $(RPI3_STOCK_FW_PATH)/boot/bootcode.bin && \
		ln -sf $(RPI3_STOCK_FW_PATH)/boot/COPYING.linux && \
		ln -sf $(RPI3_STOCK_FW_PATH)/boot/fixup_cd.dat && \
		ln -sf $(RPI3_STOCK_FW_PATH)/boot/fixup.dat && \
		ln -sf $(RPI3_STOCK_FW_PATH)/boot/fixup_db.dat && \
		ln -sf $(RPI3_STOCK_FW_PATH)/boot/fixup_x.dat && \
		ln -sf $(RPI3_STOCK_FW_PATH)/boot/LICENCE.broadcom && \
		ln -sf $(RPI3_STOCK_FW_PATH)/boot/start_cd.elf && \
		ln -sf $(RPI3_STOCK_FW_PATH)/boot/start_db.elf && \
		ln -sf $(RPI3_STOCK_FW_PATH)/boot/start.elf && \
		ln -sf $(RPI3_STOCK_FW_PATH)/boot/start_x.elf
	cd $(ROOT)/out && tar -chvzf $(BOOT_FS_FILE) boot --owner=0 --group=0 --mode=755

.PHONY: archive-boot-clean
archive-boot-clean:
	rm -rf $(BOOT_TARGET) && rm -rf $(BOOT_FS_FILE)

.PHONY: update_rootfs
update_rootfs: arm-tf u-boot
update_rootfs: update_rootfs-common

# Creating images etc, could wipe out a drive on the system, therefore we don't
# want to automate that in script or make target. Instead we just simply provide
# the steps here.
.PHONY: img-help
img-help:
	@echo "$$ fdisk /dev/sdx   # where sdx is the name of your sd-card"
	@echo "   > p             # prints partition table"
	@echo "   > d             # repeat until all partitions are deleted"
	@echo "   > n             # create a new partition"
	@echo "   > p             # create primary"
	@echo "   > 1             # make it the first partition"
	@echo "   > <enter>       # use the default sector"
	@echo "   > +64M          # create a boot partition with 64MB of space"
	@echo "   > n             # create rootfs partition"
	@echo "   > p"
	@echo "   > 2"
	@echo "   > <enter>"
	@echo "   > <enter>       # fill the remaining disk, adjust size to fit your needs"
	@echo "   > t             # change partition type"
	@echo "   > 1             # select first partition"
	@echo "   > e             # use type 'e' (FAT16)"
	@echo "   > a             # make partition bootable"
	@echo "   > 1             # select first partition"
	@echo "   > p             # double check everything looks right"
	@echo "   > w             # write partition table to disk."
	@echo ""
	@echo "run the following as root"
	@echo "   $$ mkfs.vfat -F16 -n BOOT /dev/sdx1"
	@echo "   $$ mkdir -p /media/boot"
	@echo "   $$ mount /dev/sdx1 /media/boot"
	@echo "   $$ cd /media/boot"
	@echo "   $$ tar -xpvzf $(BOOT_FS_FILE)"
	@echo "   $$ cd .. && umount boot"
	@echo ""
	@echo "run the following as root"
	@echo "   $$ mkfs.ext4 -L rootfs /dev/sdx2"
	@echo "   $$ mkdir -p /media/rootfs"
	@echo "   $$ mount /dev/sdx2 /media/rootfs"
	@echo "   $$ cd rootfs"
	@echo "   $$ gunzip -cd $(GEN_ROOTFS_PATH)/filesystem.cpio.gz | sudo cpio -idmv"
	@echo "   $$ rm -rf /media/rootfs/boot/*"
	@echo "   $$ cd .. && umount rootfs"
