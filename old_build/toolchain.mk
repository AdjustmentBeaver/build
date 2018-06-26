################################################################################
# Toolchains
################################################################################
include head.mk

TOOLCHAIN_ROOT	?= $(ROOT)/toolchains

LINARO_TOOLCHAIN_RELEASE ?= 7.2-2017.11
LINARO_TOOLCHAIN_VERSION ?= 7.2.1-2017.11

AARCH32_PATH					?= $(TOOLCHAIN_ROOT)/aarch32
AARCH32_CROSS_COMPILE	?= $(AARCH32_PATH)/bin/arm-linux-gnueabihf-
AARCH32_GCC_VERSION		?= gcc-linaro-$(LINARO_TOOLCHAIN_VERSION)-x86_64_arm-linux-gnueabihf
SRC_AARCH32_GCC				?= https://releases.linaro.org/components/toolchain/binaries/$(LINARO_TOOLCHAIN_RELEASE)/arm-linux-gnueabihf/${AARCH32_GCC_VERSION}.tar.xz

AARCH64_PATH					?= $(TOOLCHAIN_ROOT)/aarch64
AARCH64_CROSS_COMPILE	?= $(AARCH64_PATH)/bin/aarch64-linux-gnu-
AARCH64_GCC_VERSION		?= gcc-linaro-$(LINARO_TOOLCHAIN_VERSION)-x86_64_aarch64-linux-gnu
SRC_AARCH64_GCC				?= https://releases.linaro.org/components/toolchain/binaries/$(LINARO_TOOLCHAIN_RELEASE)/aarch64-linux-gnu/${AARCH64_GCC_VERSION}.tar.xz

# Download toolchain macro for saving some repetition
# $(1) is $AARCH.._PATH		: i.e., path to the destination
# $(2) is $SRC_AARCH.._GCC	: is the downloaded tar.gz file
# $(3) is $.._GCC_VERSION	: the name of the file to download
define dltc
	@if [ ! -d "$(1)" ]; then \
		echo "Downloading $(3) ..."; \
		curl -s -L $(2) -o $(TOOLCHAIN_ROOT)/$(3).tar.xz; \
		mkdir -p $(1); \
		tar xf $(TOOLCHAIN_ROOT)/$(3).tar.xz -C $(1) --strip-components=1; \
	fi
endef

toolchains: $(AARCH32_PATH) $(AARCH64_PATH)

$(AARCH32_PATH):
	mkdir -p $(TOOLCHAIN_ROOT)
	$(call dltc,$(AARCH32_PATH),$(SRC_AARCH32_GCC),$(AARCH32_GCC_VERSION))

$(AARCH64_PATH):
	mkdir -p $(TOOLCHAIN_ROOT)
	$(call dltc,$(AARCH64_PATH),$(SRC_AARCH64_GCC),$(AARCH64_GCC_VERSION))

.PHONY: toolchains-clean
toolchains-clean:
	rm -rf $(TOOLCHAIN_ROOT)
