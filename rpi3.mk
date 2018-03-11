################################################################################
# Raspberry Pi 3
################################################################################
include head.mk
include toolchain.mk
include optee.mk
include uboot.mk
include linux.mk

################################################################################
# Targets
################################################################################
all: toolchains arm-tf optee-os optee-client xtest u-boot \
	linux gen-pubkey update_rootfs archive-boot
clean: arm-tf-clean busybox-clean u-boot-clean optee-os-clean \
	optee-client-clean gen-pubkey-clean archive-boot-clean \
	linux-clean xtest-clean update_rootfs-clean

################################################################################
# Root FS
################################################################################
.PHONY: filelist-tee
filelist-tee: linux fl:=$(GEN_ROOTFS_FILELIST)
filelist-tee: optee-client xtest
	@echo "# filelist-tee /start" 				> $(fl)
	@echo "dir /lib/optee_armtz 755 0 0" 				>> $(fl)
	@if [ -e $(OPTEE_EXAMPLES_PATH)/out/ca ]; then \
		for file in $(OPTEE_EXAMPLES_PATH)/out/ca/*; do \
			echo "file /usr/bin/$$(basename $$file)" \
			"$$file 755 0 0"				>> $(fl); \
		done; \
	fi
	@if [ -e $(OPTEE_EXAMPLES_PATH)/out/ta ]; then \
		for file in $(OPTEE_EXAMPLES_PATH)/out/ta/*; do \
			echo "file /lib/optee_armtz/$$(basename $$file)" \
			"$$file 755 0 0"				>> $(fl); \
		done; \
	fi
	@echo "# xtest / optee_test" 					>> $(fl)
	@find $(OPTEE_TEST_OUT_PATH) -type f -name "xtest" | \
		sed 's/\(.*\)/file \/bin\/xtest \1 755 0 0/g' 		>> $(fl)
	@find $(OPTEE_TEST_OUT_PATH) -name "*.ta" | \
		sed 's/\(.*\)\/\(.*\)/file \/lib\/optee_armtz\/\2 \1\/\2 444 0 0/g' \
									>> $(fl)
	@echo "# Secure storage dir" 					>> $(fl)
	@echo "dir /data 755 0 0" 					>> $(fl)
	@echo "dir /data/tee 755 0 0" 					>> $(fl)
	@if [ -e $(OPTEE_GENDRV_MODULE) ]; then \
		echo "# OP-TEE device" 					>> $(fl); \
		echo "dir /lib/modules 755 0 0" 			>> $(fl); \
		echo "dir /lib/modules/$(call KERNEL_VERSION) 755 0 0" \
									>> $(fl); \
		echo "file /lib/modules/$(call KERNEL_VERSION)/optee.ko" \
			"$(OPTEE_GENDRV_MODULE) 755 0 0" \
									>> $(fl); \
	fi
	@echo "# OP-TEE Client" 					>> $(fl)
	@echo "file /bin/tee-supplicant $(OPTEE_CLIENT_EXPORT)/bin/tee-supplicant 755 0 0" \
									>> $(fl)
	@echo "file /lib/libteec.so.1.0 $(OPTEE_CLIENT_EXPORT)/lib/libteec.so.1.0 755 0 0" \
									>> $(fl)
	@echo "slink /lib/libteec.so.1 libteec.so.1.0 755 0 0"			>> $(fl)
	@echo "slink /lib/libteec.so libteec.so.1 755 0 0" 			>> $(fl)
	@if [ -e $(OPTEE_CLIENT_EXPORT)/lib/libsqlfs.so.1.0 ]; then \
		echo "file /lib/libsqlfs.so.1.0" \
			"$(OPTEE_CLIENT_EXPORT)/lib/libsqlfs.so.1.0 755 0 0" \
									>> $(fl); \
		echo "slink /lib/libsqlfs.so.1 libsqlfs.so.1.0 755 0 0" >> $(fl); \
		echo "slink /lib/libsqlfs.so libsqlfs.so.1 755 0 0" 	>> $(fl); \
	fi
	@echo "file /etc/init.d/optee $(BUILD_PATH)/init.d.optee 755 0 0"	>> $(fl)
	@echo "slink /etc/rc.d/S09_optee /etc/init.d/optee 755 0 0"	>> $(fl)
	@echo "dir /usr/bin 755 0 0" >> $(GEN_ROOTFS_FILELIST)
	@cd $(MODULE_OUTPUT) && find ! -path . -type d | sed 's/\.\(.*\)/dir \1 755 0 0/g' >> $(GEN_ROOTFS_FILELIST)
	@cd $(MODULE_OUTPUT) && find -type f | sed "s|\.\(.*\)|file \1 $(MODULE_OUTPUT)\1 755 0 0|g" >> $(GEN_ROOTFS_FILELIST)
	@echo "# filelist-tee /end"				>> $(fl)

update_rootfs: arm-tf u-boot
update_rootfs: update_rootfs-common

update_rootfs: busybox filelist-tee
	cat $(GEN_ROOTFS_PATH)/filelist-final.txt > $(GEN_ROOTFS_PATH)/filelist.tmp
	cat $(GEN_ROOTFS_FILELIST) >> $(GEN_ROOTFS_PATH)/filelist.tmp
	cd $(GEN_ROOTFS_PATH) && \
	        $(LINUX_PATH)/usr/gen_init_cpio $(GEN_ROOTFS_PATH)/filelist.tmp | \
			gzip > $(GEN_ROOTFS_PATH)/filesystem.cpio.gz

.PHONY: update_rootfs-clean
update_rootfs-clean:
	rm -f $(GEN_ROOTFS_PATH)/filesystem.cpio.gz
	rm -f $(GEN_ROOTFS_PATH)/filelist-all.txt
	rm -f $(GEN_ROOTFS_PATH)/filelist-tmp.txt
	rm -f $(GEN_ROOTFS_FILELIST)

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
	cd $(ROOT)/out && tar -chvzf $(BOOT_FS_FILE) boot --owner=0 --group=0 --mode=755

.PHONY: archive-boot-clean
archive-boot-clean:
	rm -rf $(BOOT_TARGET) && rm -rf $(BOOT_FS_FILE)

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
