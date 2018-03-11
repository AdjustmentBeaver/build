################################################################################
# OP-TEE and Trusted Firmware
################################################################################
include head.mk

################################################################################
# OP-TEE
################################################################################
 OPTEE_OS_FLAGS ?= \
	$(OPTEE_OS_EXTRA_FLAGS) \
	CROSS_COMPILE=$(CROSS_COMPILE_S_USER) \
	CROSS_COMPILE_core=$(CROSS_COMPILE_S_KERNEL) \
	CROSS_COMPILE_ta_arm64=$(AARCH64_CROSS_COMPILE) \
	CROSS_COMPILE_ta_arm32=$(AARCH32_CROSS_COMPILE) \
	CFG_TEE_CORE_LOG_LEVEL=$(CFG_TEE_CORE_LOG_LEVEL) \
	DEBUG=$(DEBUG) \
	PLATFORM=rpi3

OPTEE_OS_CLEAN_FLAGS ?= $(OPTEE_OS_EXTRA_FLAGS) PLATFORM=rpi3

OPTEE_CLIENT_FLAGS ?= CROSS_COMPILE=$(CROSS_COMPILE_NS_USER)

optee-os: toolchains
	$(MAKE) -C $(OPTEE_OS_PATH) $(OPTEE_OS_FLAGS)

.PHONY: optee-os-clean
optee-os-clean: xtest-clean
	$(MAKE) -C $(OPTEE_OS_PATH) $(OPTEE_OS_CLEAN_FLAGS) clean

optee-client: toolchains
	$(MAKE) -C $(OPTEE_CLIENT_PATH) $(OPTEE_CLIENT_FLAGS)

.PHONY: optee-client-clean
optee-client-clean:
	$(MAKE) -C $(OPTEE_CLIENT_PATH) $(OPTEE_CLIENT_CLEAN_FLAGS) \
		clean

################################################################################
# xtest / optee_test
################################################################################
XTEST_FLAGS ?= CROSS_COMPILE_HOST=$(CROSS_COMPILE_NS_USER)\
	CROSS_COMPILE_TA=$(CROSS_COMPILE_S_USER) \
	TA_DEV_KIT_DIR=$(OPTEE_OS_TA_DEV_KIT_DIR) \
	OPTEE_CLIENT_EXPORT=$(OPTEE_CLIENT_EXPORT) \
	COMPILE_NS_USER=$(COMPILE_NS_USER) \
	O=$(OPTEE_TEST_OUT_PATH)

XTEST_CLEAN_FLAGS ?= O=$(OPTEE_TEST_OUT_PATH) \
	TA_DEV_KIT_DIR=$(OPTEE_OS_TA_DEV_KIT_DIR) \

XTEST_PATCH_FLAGS ?= $(XTEST_FLAGS)

xtest: optee-os optee-client
	$(MAKE) -C $(OPTEE_TEST_PATH) $(XTEST_FLAGS)

.PHONY: xtest-clean-common
xtest-clean:
	$(MAKE) -C $(OPTEE_TEST_PATH) $(XTEST_CLEAN_FLAGS) clean

xtest-patch:
	$(MAKE) -C $(OPTEE_TEST_PATH) $(XTEST_PATCH_FLAGS) patch

################################################################################
# ARM Trusted Firmware
################################################################################
ARM_TF_PATH		?= $(ROOT)/arm-trusted-firmware
ARM_TF_OUT		?= $(ARM_TF_PATH)/build/rpi3/debug
ARM_TF_BIN		?= $(ARM_TF_OUT)/bl31.bin
ARM_TF_TMP		?= $(ARM_TF_OUT)/bl31.tmp
ARM_TF_HEAD		?= $(ARM_TF_OUT)/bl31.head
ARM_TF_BOOT		?= $(ARM_TF_OUT)/optee.bin

ARM_TF_EXPORTS ?= \
	CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

ARM_TF_FLAGS ?= \
	BL32=$(OPTEE_OS_BIN) \
	DEBUG=1 \
	V=0 \
	CRASH_REPORTING=1 \
	LOG_LEVEL=40 \
	PLAT=rpi3 \
	SPD=opteed

arm-tf: optee-os
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ARM_TF_PATH) $(ARM_TF_FLAGS) all
	cd $(ARM_TF_OUT) && \
	  dd if=/dev/zero of=scratch bs=1c count=131072 && \
	  cat $(ARM_TF_BIN) scratch > $(ARM_TF_TMP) && \
	  dd if=$(ARM_TF_TMP) of=$(ARM_TF_HEAD) bs=1c count=131072 && \
	  cat $(ARM_TF_HEAD) $(OPTEE_OS_PAGER) > $(ARM_TF_BOOT) && \
	  rm scratch $(ARM_TF_TMP) $(ARM_TF_HEAD)

.PHONY: arm-tf-clean
arm-tf-clean:
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ARM_TF_PATH) $(ARM_TF_FLAGS) clean
