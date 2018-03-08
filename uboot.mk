################################################################################
# U-Boot
################################################################################
include head.mk
include common.mk

U-BOOT_PATH			?= $(ROOT)/u-boot
U-BOOT_BIN			?= $(U-BOOT_PATH)/u-boot.bin
U-BOOT_RPI_BIN	?= $(U-BOOT_PATH)/u-boot-rpi.bin

MKIMAGE_PATH ?= $(U-BOOT_PATH)/tools/mkimage

U-BOOT_DEFAULT_EXPORTS ?= CROSS_COMPILE=$(LEGACY_AARCH64_CROSS_COMPILE) ARCH=arm64
U-BOOT_EXPORTS ?= $(U-BOOT_DEFAULT_EXPORTS) EXT_DTB=$(ROOT)/out/fit/$(PUBKEY_DTB)

$(MKIMAGE_PATH): $(RPI3_HEAD_BIN)
	$(U-BOOT_DEFAULT_EXPORTS) EXT_DTB=$(RPI3_STOCK_FW_PATH_BOOT)/bcm2710-rpi-3-b.dtb $(MAKE) -C $(U-BOOT_PATH) tools

u-boot: $(MKIMAGE_PATH)
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) rpi_3_defconfig
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) all

.PHONY: u-boot-clean
u-boot-clean:
	$(U-BOOT_DEFAULT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) clean

u-boot-rpi-bin: $(RPI3_UBOOT_ENV) u-boot
	cd $(U-BOOT_PATH) && cat $(RPI3_HEAD_BIN) $(U-BOOT_BIN) > $(U-BOOT_RPI_BIN)

.PHONY: u-boot-rpi-clean
u-boot-rpi-bin-clean:
	rm -f $(U-BOOT_RPI_BIN)

$(RPI3_HEAD_BIN): $(RPI3_FIRMWARE_PATH)/head.S
	mkdir -p $(ROOT)/out/
	$(AARCH64_CROSS_COMPILE)as $< -o $(ROOT)/out/head.o
	$(AARCH64_CROSS_COMPILE)objcopy -O binary $(ROOT)/out/head.o $@

.PHONY: head-bin-clean
head-bin-clean:
	rm -f $(RPI3_HEAD_BIN) $(ROOT)/out/head.o

$(RPI3_UBOOT_ENV): $(RPI3_UBOOT_ENV_TXT) u-boot
	mkdir -p $(ROOT)/out
	$(U-BOOT_PATH)/tools/mkenvimage -s 0x4000 -o $(ROOT)/out/uboot.env $(RPI3_UBOOT_ENV_TXT)

.PHONY: u-boot-env-clean
u-boot-env-clean:
	rm -f $(RPI3_UBOOT_ENV)

$(ROOT)/out/fit/keys/dev.crt:
	mkdir -p $(ROOT)/out/fit/keys && cd $(ROOT)/out/fit/keys && \
	openssl genrsa -F4 -out dev.key 2048 && \
	openssl req -batch -new -x509 -key dev.key -out dev.crt

gen-pubkey: $(ROOT)/out/fit/keys/dev.crt ;

.PHONY: gen-pubkey-clean
gen-pubkey-clean:
		rm -rf $(ROOT)/out/fit/keys

u-boot-fit: $(MKIMAGE_PATH) linux arm-tf gen-pubkey
	mkdir -p $(ROOT)/out/fit
	cd $(ROOT)/out/fit && ln -sf $(LINUX_IMAGE) && ln -sf $(ARM_TF_BOOT) && ln -sf $(LINUX_DTB) && ln -sf $(RPI3_FIRMWARE_PATH)/rpi3_fit.its && cp $(LINUX_DTB) rpi3_pubkey.dtb
	cd $(ROOT)/out/fit && $(MKIMAGE_PATH) -f rpi3_fit.its -K rpi3_pubkey.dtb -k keys -r image.fit

u-boot-fit-clean:
	rm -rf $(ROOT)/out/fit
