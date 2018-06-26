OPTEE_OS_VERSION = 3.1.0
OPTEE_OS_SITE = $(BR2_PACKAGE_OPTEE_OS_SITE)
OPTEE_OS_SITE_METHOD = git
OPTEE_OS_INSTALL_TARGET = YES
OPTEE_OS_INSTALL_STAGING = YES
OPTEE_OS_INSTALL_IMAGES = YES

define OPTEE_OS_BUILD_CMDS
	$(MAKE) -C $(@D) $(TARGET_CONFIGURE_OPTS) \
	PLATFORM=$(BR2_PACKAGE_OPTEE_OS_PLATFORM) \
	DEBUG=y \
	NOWERROR=1 \
	CFG_TEE_CORE_LOG_LEVEL=3 \
	CFG_TEE_CORE_DEBUG=y \
ifeq ($(BR2_PACKAGE_OPTEE_OS_64BIT), y)
	CROSS_COMPILE64=$(TARGET_CROSS) \
	CFG_ARM64_core=y
else
	CROSS_COMPILE=$(TARGET_CROSS) \
	CFG_ARM32_core=y
endif
endef

define OPTEE_OS_INSTALL_STAGING_CMDS
ifeq ($(BR2_PACKAGE_OPTEE_OS_64BIT), y)
	rsync -a $(@D)/out/arm-plat-$(BR2_PACKAGE_OPTEE_OS_PLATFORM)/export-ta_arm64/ $(STAGING_DIR)/ta_dev_kit
else
	rsync -a $(@D)/out/arm-plat-$(BR2_PACKAGE_OPTEE_OS_PLATFORM)/export-ta_arm32/ $(STAGING_DIR)/ta_dev_kit
endif
endef

define OPTEE_OS_INSTALL_IMAGES_CMDS
	$(INSTALL) -D $(@D)/out/arm-plat-$(BR2_PACKAGE_OPTEE_OS_PLATFORM)/core/tee-pager.bin $(BINARIES_DIR)/tee-pager.bin
	$(INSTALL) -D $(@D)/out/arm-plat-$(BR2_PACKAGE_OPTEE_OS_PLATFORM)/core/tee.bin $(BINARIES_DIR)/tee.bin
endef

$(eval $(generic-package))