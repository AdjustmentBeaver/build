OPTEE_OS_VERSION = 3.1.0
#OPTEE_OS_SOURCE = $(OPTEE_OS_VERSION).tar.gz
OPTEE_OS_SITE = $(BR2_PACKAGE_OPTEE_OS_SITE)
#OPTEE_OS_SITE_METHOD = local
OPTEE_OS_INSTALL_TARGET = YES
OPTEE_OS_INSTALL_STAGING = YES
OPTEE_OS_INSTALL_IMAGES = YES
OPTEE_OS_SDK = $(BR2_PACKAGE_OPTEE_OS_SDK)
OPTEE_OS_CONF_OPTS = -DOPTEE_OS_SDK=$(OPTEE_OS_SDK)

define OPTEE_OS_BUILD_CMDS
        $(MAKE) -C $(@D) $(TARGET_CONFIGURE_OPTS) \
	PLATFORM=imx-mx6qsabresd \
	ARCH=arm \
	CFG_BUILT_IN_ARGS=y \
	CFG_PAGEABLE_ADDR=0 \
	CFG_NS_ENTRY_ADDR=0x12000000 \
	CFG_DT_ADDR=0x18000000 \
	CFG_DT=y \
	CFG_PSCI_ARM32=y \
	DEBUG=y \
	NOWERROR=1 \
	CFG_TEE_CORE_LOG_LEVEL=3 \
	CFG_TEE_CORE_DEBUG=y \
	CFG_BOOT_SYNC_CPU=n \
	CFG_BOOT_SECONDARY_REQUEST=y \
	CROSS_COMPILE=$(TARGET_CROSS)

#        $(MAKE) -C $(@D)/ta_services/secure_key_services/ O=out CROSS_COMPILE=$(TARGET_CROSS) TA_DEV_KIT_DIR=$(@D)/out/arm-plat-imx/export-ta_arm32
endef


#For TA Devkit
define OPTEE_OS_INSTALL_STAGING_CMDS
	rsync -a $(@D)/out/arm-plat-imx/export-ta_arm32/ $(STAGING_DIR)/ta_dev_kit
endef

# optee binary image
define OPTEE_OS_INSTALL_IMAGES_CMDS
	$(INSTALL) -D $(@D)/out/arm-plat-imx/core/tee.bin $(BINARIES_DIR)/tee.bin
endef

#define OPTEE_OS_INSTALL_TARGET_CMDS
#	find $(@D)/ta_services/secure_key_services/out/ -name "*\.ta" -exec cp {} $(TARGET_DIR)/lib/optee_armtz/ \; -o -name "*\.elf" -exec cp {} $(TARGET_DIR)/lib/optee_armtz/ \;
#endef

$(eval $(generic-package))
