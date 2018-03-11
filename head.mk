ifndef HEAD_INCLUDED
HEAD_INCLUDED = 1

################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
override COMPILE_NS_USER   := 64
override COMPILE_NS_KERNEL := 64
override COMPILE_S_USER    := 64
override COMPILE_S_KERNEL  := 64

ROOT ?= $(shell cd .. && pwd)

SHELL := bash
BASH ?= bash

BUILD_PATH			?= $(ROOT)/build
LINUX_PATH			?= $(ROOT)/linux
OPTEE_GENDRV_MODULE		?= $(LINUX_PATH)/drivers/tee/optee/optee.ko
GEN_ROOTFS_PATH			?= $(ROOT)/gen_rootfs
GEN_ROOTFS_FILELIST		?= $(GEN_ROOTFS_PATH)/filelist-tee.txt
OPTEE_OS_PATH			?= $(ROOT)/optee_os
OPTEE_CLIENT_PATH		?= $(ROOT)/optee_client
OPTEE_CLIENT_EXPORT		?= $(OPTEE_CLIENT_PATH)/out/export
OPTEE_TEST_PATH			?= $(ROOT)/optee_test
OPTEE_TEST_OUT_PATH		?= $(ROOT)/optee_test/out
OPTEE_EXAMPLES_PATH		?= $(ROOT)/optee_examples
BENCHMARK_APP_PATH		?= $(ROOT)/optee_benchmark
BENCHMARK_APP_OUT		?= $(BENCHMARK_APP_PATH)/out
LIBYAML_LIB_OUT			?= $(BENCHMARK_APP_OUT)/libyaml/out/lib

# default high verbosity. slow uarts shall specify lower if prefered
CFG_TEE_CORE_LOG_LEVEL		?= 3

# default disable latency benchmarks (over all OP-TEE layers)
CFG_TEE_BENCHMARK		?= n

CCACHE ?= $(shell which ccache) # Don't remove this comment (space is needed)

################################################################################
# Mandatory for autotools (for specifying --host)
################################################################################
ifeq ($(COMPILE_NS_USER),64)
MULTIARCH			:= aarch64-linux-gnu
else
MULTIARCH			:= arm-linux-gnueabihf
endif

################################################################################
# Check coherency of compilation mode
################################################################################

ifneq ($(COMPILE_NS_USER),)
ifeq ($(COMPILE_NS_KERNEL),)
$(error COMPILE_NS_KERNEL must be defined as COMPILE_NS_USER=$(COMPILE_NS_USER) is defined)
endif
ifeq (,$(filter $(COMPILE_NS_USER),32 64))
$(error COMPILE_NS_USER=$(COMPILE_NS_USER) - Should be 32 or 64)
endif
endif

ifneq ($(COMPILE_NS_KERNEL),)
ifeq ($(COMPILE_NS_USER),)
$(error COMPILE_NS_USER must be defined as COMPILE_NS_KERNEL=$(COMPILE_NS_KERNEL) is defined)
endif
ifeq (,$(filter $(COMPILE_NS_KERNEL),32 64))
$(error COMPILE_NS_KERNEL=$(COMPILE_NS_KERNEL) - Should be 32 or 64)
endif
endif

ifeq ($(COMPILE_NS_KERNEL),32)
ifneq ($(COMPILE_NS_USER),32)
$(error COMPILE_NS_USER=$(COMPILE_NS_USER) - Should be 32 as COMPILE_NS_KERNEL=$(COMPILE_NS_KERNEL))
endif
endif

ifneq ($(COMPILE_S_USER),)
ifeq ($(COMPILE_S_KERNEL),)
$(error COMPILE_S_KERNEL must be defined as COMPILE_S_USER=$(COMPILE_S_USER) is defined)
endif
ifeq (,$(filter $(COMPILE_S_USER),32 64))
$(error COMPILE_S_USER=$(COMPILE_S_USER) - Should be 32 or 64)
endif
endif

ifneq ($(COMPILE_S_KERNEL),)
OPTEE_OS_COMMON_EXTRA_FLAGS ?= O=out/arm
OPTEE_OS_BIN		    ?= $(OPTEE_OS_PATH)/out/arm/core/tee.bin
OPTEE_OS_HEADER_V2_BIN	    ?= $(OPTEE_OS_PATH)/out/arm/core/tee-header_v2.bin
OPTEE_OS_PAGER_V2_BIN	    ?= $(OPTEE_OS_PATH)/out/arm/core/tee-pager_v2.bin
OPTEE_OS_PAGEABLE_V2_BIN    ?= $(OPTEE_OS_PATH)/out/arm/core/tee-pageable_v2.bin
ifeq ($(COMPILE_S_USER),)
$(error COMPILE_S_USER must be defined as COMPILE_S_KERNEL=$(COMPILE_S_KERNEL) is defined)
endif
ifeq (,$(filter $(COMPILE_S_KERNEL),32 64))
$(error COMPILE_S_KERNEL=$(COMPILE_S_KERNEL) - Should be 32 or 64)
endif
endif

ifeq ($(COMPILE_S_KERNEL),32)
ifneq ($(COMPILE_S_USER),32)
$(error COMPILE_S_USER=$(COMPILE_S_USER) - Should be 32 as COMPILE_S_KERNEL=$(COMPILE_S_KERNEL))
endif
endif


################################################################################
# set the compiler when COMPILE_xxx are defined
################################################################################
CROSS_COMPILE_NS_USER   ?= "$(CCACHE)$(AARCH$(COMPILE_NS_USER)_CROSS_COMPILE)"
CROSS_COMPILE_NS_KERNEL ?= "$(CCACHE)$(AARCH$(COMPILE_NS_KERNEL)_CROSS_COMPILE)"
CROSS_COMPILE_S_USER    ?= "$(CCACHE)$(AARCH$(COMPILE_S_USER)_CROSS_COMPILE)"
CROSS_COMPILE_S_KERNEL  ?= "$(CCACHE)$(AARCH$(COMPILE_S_KERNEL)_CROSS_COMPILE)"

ifeq ($(COMPILE_S_USER),32)
OPTEE_OS_TA_DEV_KIT_DIR	?= $(OPTEE_OS_PATH)/out/arm/export-ta_arm32
endif
ifeq ($(COMPILE_S_USER),64)
OPTEE_OS_TA_DEV_KIT_DIR	?= $(OPTEE_OS_PATH)/out/arm/export-ta_arm64
endif

ifeq ($(COMPILE_S_KERNEL),64)
OPTEE_OS_COMMON_EXTRA_FLAGS	+= CFG_ARM64_core=y
endif


################################################################################
# defines, macros, configuration etc
################################################################################
define KERNEL_VERSION
$(shell cd $(LINUX_PATH) && $(MAKE) --no-print-directory kernelversion)
endef

# Read stdin, expand ${VAR} environment variables, output to stdout
# http://superuser.com/a/302847
define expand-env-var
awk '{while(match($$0,"[$$]{[^}]*}")) {var=substr($$0,RSTART+2,RLENGTH -3);gsub("[$$]{"var"}",ENVIRON[var])}}1'
endef

DEBUG ?= 0

RPI3_FIRMWARE_PATH			?= $(BUILD_PATH)/rpi3/firmware
RPI3_HEAD_BIN						?= $(ROOT)/out/head.bin
RPI3_BOOT_CONFIG				?= $(RPI3_FIRMWARE_PATH)/config.txt
RPI3_UBOOT_ENV					?= $(ROOT)/out/uboot.env
RPI3_UBOOT_ENV_TXT			?= $(RPI3_FIRMWARE_PATH)/uboot.env.txt
RPI3_STOCK_FW_PATH			?= $(ROOT)/firmware
RPI3_STOCK_FW_PATH_BOOT	?= $(RPI3_STOCK_FW_PATH)/boot
OPTEE_OS_PAGER					?= $(OPTEE_OS_PATH)/out/arm/core/tee-pager.bin
RPI3_DTB								?= $(RPI3_STOCK_FW_PATH_BOOT)/bcm2710-rpi-3-b.dtb

LINUX_IMAGE			?= $(LINUX_PATH)/arch/arm64/boot/Image
LINUX_DTB				?= $(LINUX_PATH)/arch/arm64/boot/dts/broadcom/bcm2710-rpi-3-b.dtb
MODULE_OUTPUT		?= $(ROOT)/module_output
FIT_IMAGE				?= $(ROOT)/out/fit/image.fit

BOOT_TARGET		?= $(ROOT)/out/boot
BOOT_FS_FILE	?= $(ROOT)/out/boot.tar.gz

PUBKEY_DTB	?= rpi3_pubkey.dtb

endif
