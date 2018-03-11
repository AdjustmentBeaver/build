################################################################################
# U-Boot
################################################################################
include head.mk
include common.mk

U-BOOT_PATH				?= $(ROOT)/u-boot
U-BOOT_BIN				?= $(U-BOOT_PATH)/u-boot.bin
U-BOOT_RPI_BIN		?= $(U-BOOT_PATH)/u-boot-rpi.bin
U-BOOT_MKIMAGE		?= $(U-BOOT_PATH)/tools/mkimage
U-BOOT_MKENVIMAGE	?= $(U-BOOT_PATH)/tools/mkenvimage
U-BOOT_KEYS				?= $(ROOT)/out/fit/keys
U-BOOT_CRT				?= $(U-BOOT_KEYS)/dev.crt
U-BOOT_PUBKEY_DTB	?= $(ROOT)/out/fit/$(PUBKEY_DTB)

U-BOOT_DEFAULT_EXPORTS	?= CROSS_COMPILE=$(AARCH64_CROSS_COMPILE) ARCH=arm64
U-BOOT_EXPORTS					?= $(U-BOOT_DEFAULT_EXPORTS) EXT_DTB=$(U-BOOT_PUBKEY_DTB)

### Generate public key and certificate
$(U-BOOT_CRT):
	mkdir -p $(U-BOOT_KEYS); cd $(U-BOOT_KEYS); \
		openssl genrsa -F4 -out dev.key 2048; \
		openssl req -batch -new -x509 -key dev.key -out dev.crt

.PHONY: gen-pubkey
gen-pubkey: $(U-BOOT_CRT)
	@echo "U-Boot: Generated RSA key-pair"

.PHONY: gen-pubkey-clean
gen-pubkey-clean:
		rm -rf $(ROOT)/out/fit/keys

### Generate U-Boot Head binaries
$(RPI3_HEAD_BIN): $(RPI3_FIRMWARE_PATH)/head.S
	mkdir -p $(ROOT)/out
	$(AARCH64_CROSS_COMPILE)as $< -o $(ROOT)/out/head.o
	$(AARCH64_CROSS_COMPILE)objcopy -O binary $(ROOT)/out/head.o $@

.PHONY: u-boot-head-bin
u-boot-head-bin: $(RPI3_HEAD_BIN)
	@echo "U-Boot: RPi head binaries compiled"

.PHONY: u-boot-head-bin-clean
u-boot-head-bin-clean:
	rm -f $(RPI3_HEAD_BIN) $(ROOT)/out/head.o

### Generate U-Boot Tools
$(U-BOOT_MKIMAGE): u-boot-head-bin
	$(U-BOOT_DEFAULT_EXPORTS) EXT_DTB=$(RPI3_DTB) $(MAKE) -C $(U-BOOT_PATH) tools

.PHONY: u-boot-mkimage
u-boot-mkimage: $(U-BOOT_MKIMAGE)
	@echo "U-Boot: Tools compiled"

### Generate U-Boot env
$(RPI3_UBOOT_ENV): $(RPI3_UBOOT_ENV_TXT) u-boot
	mkdir -p $(ROOT)/out
	$(U-BOOT_MKENVIMAGE) -s 0x4000 -o $(RPI3_UBOOT_ENV) $(RPI3_UBOOT_ENV_TXT)

.PHONY: u-boot-env
u-boot-env: $(RPI3_UBOOT_ENV)
	@echo "U-Boot: Env compiled"

.PHONY: u-boot-env-clean
u-boot-env-clean:
	rm -rf $(RPI3_UBOOT_ENV)

### Generate U-Boot binaries
$(U-BOOT_RPI_BIN): u-boot-mkimage u-boot-env gen-pubkey
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) rpi_3_defconfig
	$(U-BOOT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) all
	cd $(U-BOOT_PATH); cat $(RPI3_HEAD_BIN) $(U-BOOT_BIN) > $(U-BOOT_RPI_BIN)

.PHONY: u-boot-rpi-bin
u-boot-rpi-bin: $(U-BOOT_RPI_BIN)
	@echo "U-Boot: RPi binaries compiled"

.PHONY: u-boot-rpi-bin-clean
u-boot-rpi-bin-clean:
	rm -f $(U-BOOT_RPI_BIN)

### Generate FIT image
u-boot-fit: u-boot-mkimage linux arm-tf gen-pubkey
	mkdir -p $(ROOT)/out/fit
	cd $(ROOT)/out/fit; \
	 ln -sf $(LINUX_IMAGE); ln -sf $(ARM_TF_BOOT); ln -sf $(LINUX_DTB); ln -sf $(RPI3_FIRMWARE_PATH)/rpi3_fit.its; cp $(LINUX_DTB) rpi3_pubkey.dtb; \
	 $(U-BOOT_MKIMAGE) -f rpi3_fit.its -K rpi3_pubkey.dtb -k keys -r image.fit
	@echo "U-Boot: FIT image created"

.PHONY: u-boot-fit-clean
u-boot-fit-clean:
	rm -rf $(ROOT)/out/fit

### Target for U-Boot binaries and tools
.PHONY: u-boot
u-boot: u-boot-rpi-bin u-boot-fit
	@echo "U-Boot: Finished compiling U-Boot"

.PHONY: u-boot-clean
u-boot-clean: u-boot-rpi-bin-clean u-boot-env-clean u-boot-head-bin-clean u-boot-fit-clean
	$(U-BOOT_DEFAULT_EXPORTS) $(MAKE) -C $(U-BOOT_PATH) clean
