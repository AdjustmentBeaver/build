KMOD_PSLIST_VERSION = master
KMOD_PSLIST_SITE = $(BR2_PACKAGE_KMOD_PSLIST_SITE)
KMOD_PSLIST_SITE_METHOD = git

$(eval $(kernel-module))
$(eval $(generic-package))
