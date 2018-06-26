KMOD_HEADER_VERSION = 1.0
KMOD_HEADER_SITE = $(BR2_PACKAGE_KMOD_HEADER_SITE)
KMOD_HEADER_SITE_METHOD = local

define KMOD_HEADER_BUILD_CMDS
	$(MAKE) -C $(@D) $(TARGET_CONFIGURE_OPTS) \
	ARCH=$(KERNEL_ARCH) \
	CROSS_COMPILE=$(TARGET_CROSS) \
	LINUX_DIR=$(LINUX_DIR)
endef

define KMOD_HEADER_POST_BUILD_EXDBG
	python3 $(@D)/dwarfparse/dwarfparse.py -o $(@D) $(@D)/kmod_header.ko
	mkdir -p $(STAGING_DIR)/ta_dev_kit/include
	cp $(@D)/cu_0.h $(STAGING_DIR)/ta_dev_kit/include/kmod_header.h
endef

KMOD_HEADER_POST_BUILD_HOOKS += KMOD_HEADER_POST_BUILD_EXDBG

$(eval $(generic-package))
