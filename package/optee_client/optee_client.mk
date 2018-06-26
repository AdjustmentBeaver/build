OPTEE_CLIENT_VERSION = 3.1.0
OPTEE_CLIENT_SITE = $(BR2_PACKAGE_OPTEE_CLIENT_SITE)
OPTEE_CLIENT_SITE_METHOD = git
OPTEE_CLIENT_INSTALL_STAGING = YES
OPTEE_CLIENT_DEPENDENCIES = optee_os

define OPTEE_CLIENT_INSTALL_SUPPLICANT_SCRIPT
	$(INSTALL) -m 0755 -D $(OPTEE_CLIENT_PKGDIR)/S30optee \
		$(TARGET_DIR)/etc/init.d/S30optee
endef

define OPTEE_CLIENT_INSTALL_INIT_SYSV
	$(OPTEE_CLIENT_INSTALL_SUPPLICANT_SCRIPT)
endef

$(eval $(cmake-package))
