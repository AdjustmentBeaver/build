################################################################################
# Raspberry Pi 3
################################################################################
include head.mk
include toolchain.mk
include optee.mk
include uboot.mk

################################################################################
# Targets
################################################################################
all: toolchains arm-tf optee-os optee-client xtest u-boot \
	gen-pubkey archive-boot
clean: arm-tf-clean busybox-clean u-boot-clean optee-os-clean \
	optee-client-clean gen-pubkey-clean archive-boot-clean \
	linux-clean xtest-clean update_rootfs-clean

################################################################################
# Boot FS
################################################################################
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
	cd $(ROOT)/out/boot && tar -chvf $(BOOT_FS_FILE) . --owner=0 --group=0 --mode=755

.PHONY: archive-boot-clean
archive-boot-clean:
	rm -rf $(BOOT_TARGET) && rm -rf $(BOOT_FS_FILE)

################################################################################
# Buildroot
################################################################################

BUILDROOT_PATH=$(ROOT)/buildroot
OVERLAY_PATH=$(BUILDROOT_PATH)/overlay

buildroot: buildroot-overlay
	ln -sf $(BUILD_PATH)/kconfigs/rpi3.conf $(BUILDROOT_PATH)/rpi3.conf
	sed -i 's#BR2_TOOLCHAIN_EXTERNAL_PATH="topkek"#BR2_TOOLCHAIN_EXTERNAL_PATH="$(ROOT)/toolchains/aarch64"#g' $(BUILD_PATH)/rpi3/raspberrypi3_64_custom_defconfig
	ln -sf $(BUILD_PATH)/rpi3/raspberrypi3_64_custom_defconfig $(BUILDROOT_PATH)/configs/raspberrypi3_64_custom_defconfig
	$(MAKE) -C $(BUILDROOT_PATH) raspberrypi3_64_custom_defconfig
	$(MAKE) -C $(BUILDROOT_PATH)
	ln -sf $(BUILDROOT_PATH)/output/images/rootfs.tar $(ROOT)/out

buildroot-clean:
	$(MAKE) -C $(BUILDROOT_PATH) clean

################################################################################
# Buildroot Overlay
################################################################################

buildroot-overlay:  $(OVERLAY_PATH) optee-os optee-client xtest
	@echo Building overlay...
	mkdir -p $(OVERLAY_PATH)/lib/optee_armtz
	mkdir -p $(OVERLAY_PATH)/bin
	mkdir -p $(OVERLAY_PATH)/etc/init.d
	mkdir -p $(OVERLAY_PATH)/data
	mkdir -p $(OVERLAY_PATH)/data/tee
	cp $(OPTEE_TEST_OUT_PATH)/xtest/xtest $(OVERLAY_PATH)/bin/xtest
	find $(OPTEE_TEST_OUT_PATH)/ta -name '*.ta' -exec cp {} $(OVERLAY_PATH)/lib/optee_armtz/ \;
	cp $(OPTEE_CLIENT_EXPORT)/bin/tee-supplicant $(OVERLAY_PATH)/bin/tee-supplicant
	cp $(OPTEE_CLIENT_EXPORT)/lib/libteec.so.1.0 $(OVERLAY_PATH)/lib/libteec.so.1.0
	ln -sf libteec.so.1.0 $(OVERLAY_PATH)/lib/libteec.so.1
	ln -sf libteec.so.1 $(OVERLAY_PATH)/lib/libteec.so
	cp $(BUILD_PATH)/init.d.optee $(OVERLAY_PATH)/etc/init.d/optee
	ln -sf optee $(OVERLAY_PATH)/etc/init.d/S09_optee

buildroot-overlay-clean:
	rm -rf $(OVERLAY_PATH)

################################################################################
# SD Card creation help
################################################################################
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
