OPTEE_EXAMPLES_VERSION = 3.1.0
OPTEE_EXAMPLES_SITE = $(BR2_PACKAGE_OPTEE_EXAMPLES_SITE)
OPTEE_EXAMPLES_SITE_METHOD = git
OPTEE_EXAMPLES_INSTALL_STAGING = YES
OPTEE_EXAMPLES_DEPENDENCIES = optee_client host-python-pycrypto
OPTEE_EXAMPLES_SDK = $(STAGING_DIR)/ta_dev_kit
OPTEE_EXAMPLES_CONF_OPTS = -DOPTEE_EXAMPLES_SDK=$(OPTEE_EXAMPLES_SDK)

define OPTEE_EXAMPLES_BUILD_TAS
	@$(foreach f,$(wildcard $(@D)/*/ta/Makefile), \
		echo Building $f && \
			$(MAKE) CROSS_COMPILE=$(TARGET_CROSS) \
			O=out TA_DEV_KIT_DIR=$(OPTEE_EXAMPLES_SDK) \
			$(TARGET_CONFIGURE_OPTS) -C $(dir $f) all &&) true
endef

define OPTEE_EXAMPLES_INSTALL_TAS
	@$(foreach f,$(wildcard $(@D)/*/ta/out/*.ta), \
		mkdir -p $(TARGET_DIR)/lib/optee_armtz && \
		$(INSTALL) -v -p  --mode=444 \
			--target-directory=$(TARGET_DIR)/lib/optee_armtz $f \
			&&) true
endef

OPTEE_EXAMPLES_POST_BUILD_HOOKS += OPTEE_EXAMPLES_BUILD_TAS
OPTEE_EXAMPLES_POST_INSTALL_TARGET_HOOKS += OPTEE_EXAMPLES_INSTALL_TAS

$(eval $(cmake-package))
