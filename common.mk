#
# Common definition to all platforms
#
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
ifeq ($(CFG_TEE_BENCHMARK),y)
LINUX_DEFCONFIG_BENCH ?= $(CURDIR)/kconfigs/tee_bench.conf
endif

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
# OP-TEE
################################################################################
OPTEE_OS_COMMON_FLAGS ?= \
	$(OPTEE_OS_COMMON_EXTRA_FLAGS) \
	CROSS_COMPILE=$(CROSS_COMPILE_S_USER) \
	CROSS_COMPILE_core=$(CROSS_COMPILE_S_KERNEL) \
	CROSS_COMPILE_ta_arm64=$(AARCH64_CROSS_COMPILE) \
	CROSS_COMPILE_ta_arm32=$(AARCH32_CROSS_COMPILE) \
	CFG_TEE_CORE_LOG_LEVEL=$(CFG_TEE_CORE_LOG_LEVEL) \
	DEBUG=$(DEBUG) \
	CFG_TEE_BENCHMARK=$(CFG_TEE_BENCHMARK)

optee-os-common:
	$(MAKE) -C $(OPTEE_OS_PATH) $(OPTEE_OS_COMMON_FLAGS)

OPTEE_OS_CLEAN_COMMON_FLAGS ?= $(OPTEE_OS_COMMON_EXTRA_FLAGS)

.PHONY: optee-os-clean-common
ifeq ($(CFG_TEE_BENCHMARK),y)
optee-os-clean-common: benchmark-app-clean-common
endif
optee-os-clean-common: xtest-clean optee-examples-clean
	$(MAKE) -C $(OPTEE_OS_PATH) $(OPTEE_OS_CLEAN_COMMON_FLAGS) clean

OPTEE_CLIENT_COMMON_FLAGS ?= CROSS_COMPILE=$(CROSS_COMPILE_NS_USER) \
	CFG_TEE_BENCHMARK=$(CFG_TEE_BENCHMARK) \

optee-client-common:
	$(MAKE) -C $(OPTEE_CLIENT_PATH) $(OPTEE_CLIENT_COMMON_FLAGS)

# OPTEE_CLIENT_CLEAN_COMMON_FLAGS can be defined in specific makefiles
# (hikey.mk,...) if necessary

.PHONY: optee-client-clean-common
optee-client-clean-common:
	$(MAKE) -C $(OPTEE_CLIENT_PATH) $(OPTEE_CLIENT_CLEAN_COMMON_FLAGS) \
		clean

################################################################################
# xtest / optee_test
################################################################################
XTEST_COMMON_FLAGS ?= CROSS_COMPILE_HOST=$(CROSS_COMPILE_NS_USER)\
	CROSS_COMPILE_TA=$(CROSS_COMPILE_S_USER) \
	TA_DEV_KIT_DIR=$(OPTEE_OS_TA_DEV_KIT_DIR) \
	OPTEE_CLIENT_EXPORT=$(OPTEE_CLIENT_EXPORT) \
	COMPILE_NS_USER=$(COMPILE_NS_USER) \
	O=$(OPTEE_TEST_OUT_PATH)

xtest-common: optee-os optee-client
	$(MAKE) -C $(OPTEE_TEST_PATH) $(XTEST_COMMON_FLAGS)

XTEST_CLEAN_COMMON_FLAGS ?= O=$(OPTEE_TEST_OUT_PATH) \
	TA_DEV_KIT_DIR=$(OPTEE_OS_TA_DEV_KIT_DIR) \

.PHONY: xtest-clean-common
xtest-clean-common:
	$(MAKE) -C $(OPTEE_TEST_PATH) $(XTEST_CLEAN_COMMON_FLAGS) clean

XTEST_PATCH_COMMON_FLAGS ?= $(XTEST_COMMON_FLAGS)

xtest-patch-common:
	$(MAKE) -C $(OPTEE_TEST_PATH) $(XTEST_PATCH_COMMON_FLAGS) patch

################################################################################
# sample applications / optee_examples
################################################################################
OPTEE_EXAMPLES_COMMON_FLAGS ?= HOST_CROSS_COMPILE=$(CROSS_COMPILE_NS_USER)\
	TA_CROSS_COMPILE=$(CROSS_COMPILE_S_USER) \
	TA_DEV_KIT_DIR=$(OPTEE_OS_TA_DEV_KIT_DIR) \
	TEEC_EXPORT=$(OPTEE_CLIENT_EXPORT)

optee-examples-common: optee-os optee-client
	$(MAKE) -C $(OPTEE_EXAMPLES_PATH) $(OPTEE_EXAMPLES_COMMON_FLAGS)

OPTEE_EXAMPLES_CLEAN_COMMON_FLAGS ?= TA_DEV_KIT_DIR=$(OPTEE_OS_TA_DEV_KIT_DIR)

.PHONY: optee-examples-clean-common
optee-examples-clean-common:
	$(MAKE) -C $(OPTEE_EXAMPLES_PATH) \
			$(OPTEE_EXAMPLES_CLEAN_COMMON_FLAGS) clean

################################################################################
# benchmark_app
################################################################################
BENCHMARK_APP_COMMON_FLAGS ?= CROSS_COMPILE=$(CROSS_COMPILE_NS_USER) \
	TEEC_EXPORT=$(OPTEE_CLIENT_EXPORT) \
	TEEC_INTERNAL_INCLUDES=$(OPTEE_CLIENT_PATH)/libteec \
	MULTIARCH=$(MULTIARCH)

benchmark-app-common: optee-os optee-client
	$(MAKE) -C $(BENCHMARK_APP_PATH) $(BENCHMARK_APP_COMMON_FLAGS)

.PHONY: benchmark-app-clean-common
benchmark-app-clean-common:
	$(MAKE) -C $(BENCHMARK_APP_PATH) clean

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

ifeq ($(CFG_TEE_BENCHMARK),y)
filelist-tee-common: benchmark-app
endif
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
	@if [ -e $(BENCHMARK_APP_OUT)/benchmark ]; then \
		echo "file /bin/benchmark" \
			"$(BENCHMARK_APP_OUT)/benchmark 755 0 0"	>> $(fl); \
		echo "slink /lib/libyaml-0.so.2 libyaml-0.so.2.0.5 755 0 0" \
									>> $(fl); \
		echo "file /lib/libyaml-0.so.2.0.5 $(LIBYAML_LIB_OUT)/libyaml-0.so.2.0.5 755 0 0" \
									>> $(fl); \
	fi
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
