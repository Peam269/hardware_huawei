# SPDX-License-Identifier: Apache-2.0

UNILOADER_SRC := external/uniLoader
UNILOADER_OUT := $(TARGET_OUT_INTERMEDIATES)/UNILOADER_OBJ
UNILOADER_IMAGE := $(UNILOADER_OUT)/uniLoader.gz
UNILOADER_KERNEL_DIR := $(TARGET_OUT_INTERMEDIATES)/KERNEL_OBJ/arch/arm64/boot
UNILOADER_KERNEL := $(UNILOADER_KERNEL_DIR)/Image
UNILOADER_DTS_DIR := $(TARGET_KERNEL_SOURCE)/arch/arm64/boot/dts/hisilicon/kirin970
UNILOADER_DTB_DIR := $(UNILOADER_KERNEL_DIR)/dts/hisilicon/kirin970
UNILOADER_DTBS := $(patsubst $(UNILOADER_DTS_DIR)/%.dts,$(UNILOADER_DTB_DIR)/%.dtb, \
    $(sort $(wildcard $(UNILOADER_DTS_DIR)/*/boards/*.dts)))

UNILOADER_MAKE := $(abspath prebuilts/build-tools/$(HOST_PREBUILT_TAG)/bin/make)
UNILOADER_CROSS_COMPILE := $(abspath \
    prebuilts/gcc/$(HOST_PREBUILT_TAG)/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-)
UNILOADER_BUILD_FLAGS := \
    ARCH=aarch64 \
    HOSTCC=$(TARGET_KERNEL_CLANG_PATH)/bin/clang \
    HOSTLDFLAGS=-fuse-ld=lld \
    CROSS_COMPILE=$(UNILOADER_CROSS_COMPILE)

# DTS changes must rebuild uniLoader even when the Linux image is unchanged.
UNILOADER_INPUTS := $(shell find \
    $(addprefix $(UNILOADER_SRC)/,arch board drivers lib main scripts configs) \
    -type f \( -name '*.c' -o -name '*.h' -o -name '*.S' -o -name '*.sh' \
    -o -name '*_shipped' -o -name 'Makefile*' -o -name 'Kbuild*' \
    -o -name 'Kconfig*' -o -name '*defconfig' -o -name mkmakefile \) \
    ! -path '$(UNILOADER_SRC)/scripts/tests/*')
UNILOADER_INPUTS += $(shell find $(UNILOADER_SRC)/include -type f \
    -name '*.h' ! -path '*/generated/*' ! -path '*/config/*')
UNILOADER_INPUTS += $(shell find $(UNILOADER_DTS_DIR) -type f \
    \( -name '*.dts' -o -name '*.dtsi' -o -name Makefile \))
UNILOADER_INPUTS += \
    $(UNILOADER_SRC)/Makefile \
    $(UNILOADER_SRC)/Kconfig \
    $(UNILOADER_SRC)/scripts/pack-kirin970-dtbs.py \
    hardware/huawei/uniloader.mk

# Kbuild produces Image alongside the configured compressed kernel image.
$(UNILOADER_KERNEL_DIR)/$(BOARD_KERNEL_IMAGE_NAME): .KATI_IMPLICIT_OUTPUTS += $(UNILOADER_KERNEL)

$(UNILOADER_IMAGE): $(INSTALLED_KERNEL_TARGET) $(UNILOADER_KERNEL) $(DTC) $(UNILOADER_INPUTS)
	$(call pretty,"Target Kirin970 uniLoader: $@")
	$(call make-kernel-target,dtbs)
	$(hide) mkdir -p $(UNILOADER_OUT)
	$(hide) python3 $(UNILOADER_SRC)/scripts/pack-kirin970-dtbs.py \
	    --output $(UNILOADER_OUT)/dtbs.bundle $(UNILOADER_DTBS)
	$(hide) $(UNILOADER_MAKE) -C $(UNILOADER_SRC) \
	    O=$(abspath $(UNILOADER_OUT)) $(UNILOADER_BUILD_FLAGS) kirin970_defconfig
	$(hide) $(UNILOADER_MAKE) -C $(UNILOADER_SRC) \
	    O=$(abspath $(UNILOADER_OUT)) $(UNILOADER_BUILD_FLAGS) \
	    KERNEL_PATH=$(abspath $(UNILOADER_KERNEL)) \
	    DT_PATH=$(abspath $(UNILOADER_OUT)/dtbs.bundle)

HW_BOOT_KERNEL := $(UNILOADER_IMAGE)
