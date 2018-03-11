ifndef COMMON_INCLUDED
COMMON_INCLUDED = 1

include head.mk

################################################################################
# default target is all
################################################################################
all:

################################################################################
# Busybox
################################################################################
BUSYBOX_COMMON_TARGET		?= TOBEDEFINED
BUSYBOX_CLEAN_COMMON_TARGET	?= TOBEDEFINED

busybox-common: linux
	cd $(GEN_ROOTFS_PATH) &&  \
		CROSS_COMPILE=$(CROSS_COMPILE_NS_USER) \
		PATH=${PATH}:$(LINUX_PATH)/usr \
		$(GEN_ROOTFS_PATH)/generate-cpio-rootfs.sh \
			$(BUSYBOX_COMMON_TARGET)

.PHONY: busybox-clean-common
busybox-clean-common:
	cd $(GEN_ROOTFS_PATH) && \
	$(GEN_ROOTFS_PATH)/generate-cpio-rootfs.sh  \
		$(BUSYBOX_CLEAN_COMMON_TARGET)

.PHONY: busybox-cleaner-common
busybox-cleaner-common:
	rm -rf $(GEN_ROOTFS_PATH)/build
	rm -rf $(GEN_ROOTFS_PATH)/filelist-final.txt

################################################################################
# Linux
################################################################################
LINUX_COMMON_FLAGS ?= LOCALVERSION= CROSS_COMPILE=$(CROSS_COMPILE_NS_KERNEL)

linux-common: linux-defconfig
	$(MAKE) -C $(LINUX_PATH) $(LINUX_COMMON_FLAGS)

$(LINUX_PATH)/.config: $(LINUX_DEFCONFIG_COMMON_FILES)
	cd $(LINUX_PATH) && \
		ARCH=$(LINUX_DEFCONFIG_COMMON_ARCH) \
		scripts/kconfig/merge_config.sh $(LINUX_DEFCONFIG_COMMON_FILES) \
			$(LINUX_DEFCONFIG_BENCH)

.PHONY: linux-defconfig-clean-common
linux-defconfig-clean-common:
	rm -f $(LINUX_PATH)/.config

# LINUX_CLEAN_COMMON_FLAGS should be defined in specific makefiles (hikey.mk,...)
.PHONY: linux-clean-common
linux-clean-common: linux-defconfig-clean
	$(MAKE) -C $(LINUX_PATH) $(LINUX_CLEAN_COMMON_FLAGS) clean

# LINUX_CLEANER_COMMON_FLAGS should be defined in specific makefiles (hikey.mk,...)
.PHONY: linux-cleaner-common
linux-cleaner-common: linux-defconfig-clean
	$(MAKE) -C $(LINUX_PATH) $(LINUX_CLEANER_COMMON_FLAGS) distclean

################################################################################
# rootfs
################################################################################
update_rootfs-common: busybox filelist-tee
	cat $(GEN_ROOTFS_PATH)/filelist-final.txt > $(GEN_ROOTFS_PATH)/filelist.tmp
	cat $(GEN_ROOTFS_FILELIST) >> $(GEN_ROOTFS_PATH)/filelist.tmp
	cd $(GEN_ROOTFS_PATH) && \
	        $(LINUX_PATH)/usr/gen_init_cpio $(GEN_ROOTFS_PATH)/filelist.tmp | \
			gzip > $(GEN_ROOTFS_PATH)/filesystem.cpio.gz

.PHONY: update_rootfs-clean-common
update_rootfs-clean-common:
	rm -f $(GEN_ROOTFS_PATH)/filesystem.cpio.gz
	rm -f $(GEN_ROOTFS_PATH)/filelist-all.txt
	rm -f $(GEN_ROOTFS_PATH)/filelist-tmp.txt
	rm -f $(GEN_ROOTFS_FILELIST)

filelist-tee-common: fl:=$(GEN_ROOTFS_FILELIST)
filelist-tee-common: optee-client xtest optee-examples
	@echo "# filelist-tee-common /start" 				> $(fl)
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
	@echo "# filelist-tee-common /end"				>> $(fl)

endif
