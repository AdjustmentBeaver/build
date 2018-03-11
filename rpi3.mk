################################################################################
# Raspberry Pi 3
################################################################################
include head.mk
include common.mk
include toolchain.mk
include optee.mk
include uboot.mk

################################################################################
# Targets
################################################################################
ifeq ($(CFG_TEE_BENCHMARK),y)
all: benchmark-app
clean: benchmark-app-clean
endif
all: toolchains arm-tf optee-os optee-client xtest u-boot \
	linux gen-pubkey update_rootfs optee-examples archive-boot
clean: arm-tf-clean busybox-clean u-boot-clean \
	optee-os-clean optee-client-clean \
	optee-examples-clean gen-pubkey-clean \
	archive-boot-clean linux-clean xtest-clean \

################################################################################
# Busybox
################################################################################
BUSYBOX_COMMON_TARGET = rpi3
BUSYBOX_CLEAN_COMMON_TARGET = rpi3 clean

busybox: busybox-common

.PHONY: busybox-clean
busybox-clean: busybox-clean-common

.PHONY: busybox-cleaner
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

.PHONY: linux-defconfig-clean
linux-defconfig-clean: linux-defconfig-clean-common

LINUX_CLEAN_COMMON_FLAGS += ARCH=arm64

.PHONY: linux-clean
linux-clean: linux-clean-common

LINUX_CLEANER_COMMON_FLAGS += ARCH=arm64

.PHONY: linux-cleaner
linux-cleaner: linux-cleaner-common

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
archive-boot: u-boot
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
