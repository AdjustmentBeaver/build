obj-m += $(addsuffix .o, $(notdir $(basename $(wildcard $(BR2_EXTERNAL_KERNEL_MODULE_PATH)/*.c))))

.PHONY: all clean

all:
    $(MAKE) -C '$(LINUX_DIR)' M='$(PWD)' modules

clean:
    $(MAKE) -C '$(LINUX_DIR)' M='$(PWD)' clean
