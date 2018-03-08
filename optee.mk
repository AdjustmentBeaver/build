################################################################################
# OP-TEE and Trusted Firmware
################################################################################
include head.mk
include common.mk

ARM_TF_PATH		?= $(ROOT)/arm-trusted-firmware
ARM_TF_OUT		?= $(ARM_TF_PATH)/build/rpi3/debug
ARM_TF_BIN		?= $(ARM_TF_OUT)/bl31.bin
ARM_TF_TMP		?= $(ARM_TF_OUT)/bl31.tmp
ARM_TF_HEAD		?= $(ARM_TF_OUT)/bl31.head
ARM_TF_BOOT		?= $(ARM_TF_OUT)/optee.bin

################################################################################
# ARM Trusted Firmware
################################################################################
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

################################################################################
# OP-TEE
################################################################################
OPTEE_OS_COMMON_FLAGS += PLATFORM=rpi3
optee-os: optee-os-common

OPTEE_OS_CLEAN_COMMON_FLAGS += PLATFORM=rpi3
.PHONY: optee-os-clean
optee-os-clean: optee-os-clean-common

optee-client: optee-client-common

.PHONY: optee-client-clean
optee-client-clean: optee-client-clean-common

################################################################################
# xtest / optee_test
################################################################################
xtest: xtest-common

.PHONY: xtest-clean
xtest-clean: xtest-clean-common

xtest-patch: xtest-patch-common

################################################################################
# Sample applications / optee_examples
################################################################################
optee-examples: optee-examples-common

.PHONY: optee-examples-clean
optee-examples-clean: optee-examples-clean-common

################################################################################
# benchmark
################################################################################
benchmark-app: benchmark-app-common

.PHONY: benchmark-app-clean
benchmark-app-clean: benchmark-app-clean-common
