####busybox #######
LOCAL_PATH := $(call my-dir)
BB_PATH := $(LOCAL_PATH)

# Bionic Branches Switches (GB/ICS/L)
BIONIC_ICS := true
BIONIC_L := false

# Make a static library for regex.
include $(CLEAR_VARS)
LOCAL_SRC_FILES := android/regex/bb_regex.c
LOCAL_C_INCLUDES := $(BB_PATH)/android/regex
LOCAL_CFLAGS := -Wno-sign-compare
LOCAL_MODULE := libclearsilverregex
include $(BUILD_STATIC_LIBRARY)

# Make a static library for RPC library (coming from uClibc).
include $(CLEAR_VARS)
LOCAL_SRC_FILES := $(shell cat $(BB_PATH)/android/librpc.sources)
LOCAL_C_INCLUDES := $(BB_PATH)/android/librpc
LOCAL_MODULE := libuclibcrpc
LOCAL_CFLAGS += -fno-strict-aliasing
ifeq ($(BIONIC_L),true)
LOCAL_CFLAGS += -DBIONIC_ICS -DBIONIC_L
endif
include $(BUILD_STATIC_LIBRARY)

#####################################################################

# Execute make prepare for normal config & static lib (recovery)

LOCAL_PATH := $(BB_PATH)
include $(CLEAR_VARS)

# Explicitly set an architecture specific CONFIG_CROSS_COMPILER_PREFIX
ifneq ($(filter arm arm64,$(TARGET_ARCH)),)
    BUSYBOX_CROSS_COMPILER_PREFIX := arm-linux-androideabi-
endif
ifneq ($(filter x86 x86_64,$(TARGET_ARCH)),)
    BUSYBOX_CROSS_COMPILER_PREFIX := $(if $(filter x86_64,$(HOST_ARCH)),x86_64,i686)-linux-android-
endif
ifeq ($(TARGET_ARCH),mips)
    BUSYBOX_CROSS_COMPILER_PREFIX := mipsel-linux-android-
endif

BB_PREPARE_FLAGS:=
ifeq ($(HOST_OS),darwin)
    BB_HOSTCC := $(ANDROID_BUILD_TOP)/prebuilts/gcc/darwin-x86/host/i686-apple-darwin-4.2.1/bin/i686-apple-darwin11-gcc
    BB_PREPARE_FLAGS := HOSTCC=$(BB_HOSTCC)
endif

# On aosp (master), path is relative, not on cm (kitkat)
bb_gen := $(abspath $(TARGET_OUT_INTERMEDIATES)/busybox)

busybox_prepare_full := $(bb_gen)/full/.config
$(busybox_prepare_full): $(BB_PATH)/busybox-full.config
	@echo -e ${CL_YLW}"Prepare config for busybox binary"${CL_RST}
	@rm -rf $(bb_gen)/full
	@rm -f $(addsuffix /*.o, $(abspath $(call intermediates-dir-for,EXECUTABLES,busybox)))
	@mkdir -p $(@D)
	@cat $^ > $@ && echo "CONFIG_CROSS_COMPILER_PREFIX=\"$(BUSYBOX_CROSS_COMPILER_PREFIX)\"" >> $@
	$(MAKE) -C $(BB_PATH) prepare O=$(@D) $(BB_PREPARE_FLAGS)

busybox_prepare_minimal := $(bb_gen)/minimal/.config
$(busybox_prepare_minimal): $(BB_PATH)/busybox-minimal.config
	@echo -e ${CL_YLW}"Prepare config for libbusybox"${CL_RST}
	@rm -rf $(bb_gen)/minimal
	@rm -f $(addsuffix /*.o, $(abspath $(call intermediates-dir-for,STATIC_LIBRARIES,libbusybox)))
	@mkdir -p $(@D)
	@cat $^ > $@ && echo "CONFIG_CROSS_COMPILER_PREFIX=\"$(BUSYBOX_CROSS_COMPILER_PREFIX)\"" >> $@
	$(MAKE) -C $(BB_PATH) prepare O=$(@D) $(BB_PREPARE_FLAGS)

KERNEL_MODULES_DIR ?= /system/lib/modules
BUSYBOX_CONFIG := minimal full
$(BUSYBOX_CONFIG):
	@echo -e ${CL_PFX}"prepare config for busybox $@ profile"${CL_RST}
	@cd $(BB_PATH) && make clean
	@cd $(BB_PATH) && git clean -f -- ./include-$@/
	cp $(BB_PATH)/.config-$@ $(BB_PATH)/.config
	cd $(BB_PATH) && make prepare
	@#cp $(BB_PATH)/.config $(BB_PATH)/.config-$@
	@mkdir -p $(BB_PATH)/include-$@
	cp $(BB_PATH)/include/*.h $(BB_PATH)/include-$@/
	@rm $(BB_PATH)/include/usage_compressed.h
	@rm $(BB_PATH)/include/autoconf.h
	@rm -f $(BB_PATH)/.config-old

busybox_prepare: $(BUSYBOX_CONFIG)
LOCAL_MODULE := busybox_prepare
LOCAL_MODULE_TAGS := eng debug
#include $(BUILD_STATIC_LIBRARY)

#####################################################################

LOCAL_PATH := $(BB_PATH)
include $(CLEAR_VARS)

KERNEL_MODULES_DIR ?= /system/lib/modules

SUBMAKE := make -s -C $(BB_PATH) CC=$(CC)


BUSYBOX_SRC_FILES = \
	$(shell cat $(BB_PATH)/busybox-$(BUSYBOX_CONFIG).sources) \
	android/libc/mktemp.c \
	android/android.c

ifeq ($(BIONIC_L),true)
BUSYBOX_SRC_FILES += android/libc/pty.c
endif

BUSYBOX_ASM_FILES =
ifneq ($(BIONIC_L),true)
    BUSYBOX_ASM_FILES += swapon.S swapoff.S sysinfo.S
endif

ifneq ($(filter arm x86 mips,$(TARGET_ARCH)),)
    BUSYBOX_SRC_FILES += \
        $(addprefix android/libc/arch-$(TARGET_ARCH)/syscalls/,$(BUSYBOX_ASM_FILES))
endif

BUSYBOX_C_INCLUDES = \
	$(BB_PATH)/include $(BB_PATH)/libbb \
	bionic/libc/private \
	bionic/libm/include \
	bionic/libc \
	bionic/libm \
	libc/kernel/common \
	external/libselinux/include \
	external/selinux/libsepol/include \
	$(BB_PATH)/android/regex \
	$(BB_PATH)/android/librpc

BUSYBOX_CFLAGS = \
	-Werror=implicit -Wno-clobbered \
	-Wno-implicit-function-declaration \
	-DLOGIN_NAME_MAX=128 \
	-DNDEBUG \
	-DANDROID \
	-fno-strict-aliasing \
	-fno-builtin-stpcpy \
	-include $(bb_gen)/$(BUSYBOX_CONFIG)/include/autoconf.h \
	-D'CONFIG_DEFAULT_MODULES_DIR="$(KERNEL_MODULES_DIR)"' \
	-D'BB_VER="$(strip $(shell $(SUBMAKE) kernelversion)) $(BUSYBOX_SUFFIX)"' -DBB_BT=AUTOCONF_TIMESTAMP

ifeq ($(BIONIC_L),true)
    BUSYBOX_CFLAGS += -DBIONIC_L
    BUSYBOX_AFLAGS += -DBIONIC_L
    # include changes for ICS/JB/KK
    BIONIC_ICS := true
endif

ifeq ($(BIONIC_ICS),true)
    BUSYBOX_CFLAGS += -DBIONIC_ICS
endif


# Build the static lib for the recovery tool

BUSYBOX_CONFIG:=minimal
BUSYBOX_SUFFIX:=static
LOCAL_SRC_FILES := $(BUSYBOX_SRC_FILES)
LOCAL_C_INCLUDES := $(bb_gen)/minimal/include $(BUSYBOX_C_INCLUDES)
LOCAL_CFLAGS := -Dmain=busybox_driver $(BUSYBOX_CFLAGS)
LOCAL_CFLAGS += \
  -DRECOVERY_VERSION \
  -Dgetusershell=busybox_getusershell \
  -Dsetusershell=busybox_setusershell \
  -Dendusershell=busybox_endusershell \
  -Dgetmntent=busybox_getmntent \
  -Dgetmntent_r=busybox_getmntent_r \
  -Dgenerate_uuid=busybox_generate_uuid
LOCAL_ASFLAGS := $(BUSYBOX_AFLAGS)
LOCAL_MODULE := libbusybox
LOCAL_MODULE_TAGS := eng debug
LOCAL_REQUIRED_MODULES := login
#$(LOCAL_MODULE): busybox_prepare
LOCAL_STATIC_LIBRARIES := libcutils libc libm libselinux
LOCAL_ADDITIONAL_DEPENDENCIES := $(busybox_prepare_minimal)
include $(BUILD_STATIC_LIBRARY)


# Bionic Busybox /system/xbin

LOCAL_PATH := $(BB_PATH)
include $(CLEAR_VARS)

BUSYBOX_CONFIG:=full
BUSYBOX_SUFFIX:=bionic
LOCAL_SRC_FILES := $(BUSYBOX_SRC_FILES)
LOCAL_C_INCLUDES := $(bb_gen)/full/include $(BUSYBOX_C_INCLUDES)
LOCAL_CFLAGS := $(BUSYBOX_CFLAGS)
LOCAL_ASFLAGS := $(BUSYBOX_AFLAGS)
LOCAL_CFLAGS += \
  -Dgetgrgid=busybox_getgrgid \
  -Dgetgrnam=busybox_getgrnam \
  -Dgetgrouplist=busybox_getgrouplist \
  -Dgetpwnam=busybox_getpwnam \
  -Dgetpwnam_r=busybox_getpwnam_r \
  -Dgetpwuid=busybox_getpwuid \
  -Dgetmntent=busybox_getmntent \
  -Dgetmntent_r=busybox_getmntent_r \
  -Dendpwent=busybox_endpwent

LOCAL_MODULE := busybox
LOCAL_MODULE_TAGS := eng debug
LOCAL_MODULE_PATH := $(TARGET_OUT_OPTIONAL_EXECUTABLES)
LOCAL_SHARED_LIBRARIES := libc libcutils libm
#$(LOCAL_MODULE): busybox_prepare
LOCAL_STATIC_LIBRARIES += libclearsilverregex libuclibcrpc libselinux
LOCAL_ADDITIONAL_DEPENDENCIES := $(busybox_prepare_full)
include $(BUILD_EXECUTABLE)

BUSYBOX_LINKS := $(shell cat $(BB_PATH)/busybox-$(BUSYBOX_CONFIG).links)
# nc is provided by external/netcat
exclude := nc which
SYMLINKS := $(addprefix $(TARGET_OUT_OPTIONAL_EXECUTABLES)/,$(filter-out $(exclude),$(notdir $(BUSYBOX_LINKS))))
$(SYMLINKS): BUSYBOX_BINARY := $(LOCAL_MODULE)
$(SYMLINKS): $(LOCAL_INSTALLED_MODULE)
	@echo -e ${CL_CYN}"Symlink:"${CL_RST}" $@ -> $(BUSYBOX_BINARY)"
	@mkdir -p $(dir $@)
	@rm -rf $@
	$(hide) ln -sf $(BUSYBOX_BINARY) $@

ALL_DEFAULT_INSTALLED_MODULES += $(SYMLINKS)

# We need this so that the installed files could be picked up based on the
# local module name
ALL_MODULES.$(LOCAL_MODULE).INSTALLED := \
    $(ALL_MODULES.$(LOCAL_MODULE).INSTALLED) $(SYMLINKS)

# Static Busybox

LOCAL_PATH := $(BB_PATH)
include $(CLEAR_VARS)

BUSYBOX_CONFIG:=minimal
BUSYBOX_SUFFIX:=static
LOCAL_SRC_FILES := $(BUSYBOX_SRC_FILES)
LOCAL_C_INCLUDES := $(bb_gen)/minimal/include $(BUSYBOX_C_INCLUDES)
LOCAL_CFLAGS := $(BUSYBOX_CFLAGS)
LOCAL_CFLAGS += \
  -Dgetgrgid=busybox_getgrgid \
  -Dgetgrnam=busybox_getgrnam \
  -Dgetgrouplist=busybox_getgrouplist \
  -Dgetpwnam=busybox_getpwnam \
  -Dgetpwnam_r=busybox_getpwnam_r \
  -Dgetpwuid=busybox_getpwuid \
  -Dgetmntent=busybox_getmntent \
  -Dgetmntent_r=busybox_getmntent_r \
  -Dendpwent=busybox_endpwent

LOCAL_ASFLAGS := $(BUSYBOX_AFLAGS)
LOCAL_FORCE_STATIC_EXECUTABLE := true
LOCAL_MODULE := static_busybox
LOCAL_MODULE_STEM := busybox
LOCAL_MODULE_TAGS := optional
LOCAL_STATIC_LIBRARIES := libclearsilverregex libc libcutils libm libuclibcrpc libselinux
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_PATH := $(PRODUCT_OUT)/utilities
LOCAL_UNSTRIPPED_PATH := $(PRODUCT_OUT)/symbols/utilities
#$(LOCAL_MODULE): busybox_prepare
LOCAL_ADDITIONAL_DEPENDENCIES := $(busybox_prepare_minimal)
include $(BUILD_EXECUTABLE)

BUSYBOX_LINKS := $(shell cat $(BB_PATH)/busybox-$(BUSYBOX_CONFIG).links)
# nc is provided by external/netcat
exclude := nc which
SYMLINKS := $(addprefix $(LOCAL_MODULE_PATH)/,$(filter-out $(exclude),$(notdir $(BUSYBOX_LINKS))))
$(SYMLINKS): BUSYBOX_BINARY := $(LOCAL_MODULE_STEM)
$(SYMLINKS): $(LOCAL_INSTALLED_MODULE)
	@echo -e ${CL_CYN}"Symlink:"${CL_RST}" $@ -> $(BUSYBOX_BINARY)"
	@mkdir -p $(dir $@)
	@rm -rf $@
	$(hide) ln -sf $(BUSYBOX_BINARY) $@

ALL_DEFAULT_INSTALLED_MODULES += $(SYMLINKS)

include $(CLEAR_VARS)
$(info "add console passwd protect start")
BUSYBOX_CONFIG:=minimal
BUSYBOX_SUFFIX:=static
LOCAL_C_INCLUDES := $(bb_gen)/minimal/include $(BUSYBOX_C_INCLUDES)
LOCAL_CFLAGS := $(BUSYBOX_CFLAGS)
LOCAL_ASFLAGS := $(BUSYBOX_AFLAGS)
LOCAL_CFLAGS += \
  -Dlogin_main=main \
  -Dgetgrgid=busybox_getgrgid \
  -Dgetgrnam=busybox_getgrnam \
  -Dgetgrouplist=busybox_getgrouplist \
  -Dgetpwnam=busybox_getpwnam \
  -Dgetpwnam_r=busybox_getpwnam_r \
  -Dgetpwuid=busybox_getpwuid \
  -Dgetmntent=busybox_getmntent \
  -Dgetmntent_r=busybox_getmntent_r \
  -Dendpwent=busybox_endpwent

LOCAL_MODULE_TAGS := optional
LOCAL_MODULE := login
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_PATH := $(TARGET_OUT)/bin
LOCAL_SRC_FILES := loginutils/login.c
LOCAL_STATIC_LIBRARIES := libbusybox libclearsilverregex libc libcutils libm libuclibcrpc libselinux
LOCAL_REQUIRED_MODULES := login_recovery passwd passwd_recovery
LOCAL_ADDITIONAL_DEPENDENCIES := $(busybox_prepare_minimal)
$(info "add console passwd protect end")
include $(BUILD_EXECUTABLE)

include $(CLEAR_VARS)
$(info "add console passwd protect start ---$(bb_gen)")
BUSYBOX_CONFIG:=minimal
BUSYBOX_SUFFIX:=static
LOCAL_C_INCLUDES := $(bb_gen)/minimal/include $(BUSYBOX_C_INCLUDES)
LOCAL_CFLAGS := $(BUSYBOX_CFLAGS)
LOCAL_ASFLAGS := $(BUSYBOX_AFLAGS)
LOCAL_CFLAGS += \
  -Dlogin_main=main \
  -Dgetgrgid=busybox_getgrgid \
  -Dgetgrnam=busybox_getgrnam \
  -Dgetgrouplist=busybox_getgrouplist \
  -Dgetpwnam=busybox_getpwnam \
  -Dgetpwnam_r=busybox_getpwnam_r \
  -Dgetpwuid=busybox_getpwuid \
  -Dgetmntent=busybox_getmntent \
  -Dgetmntent_r=busybox_getmntent_r \
  -Dendpwent=busybox_endpwent

LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_STEM := login
LOCAL_MODULE := login_recovery
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_PATH := $(TARGET_RECOVERY_ROOT_OUT)/sbin
LOCAL_SRC_FILES := loginutils/login.c
LOCAL_STATIC_LIBRARIES := libbusybox libclearsilverregex libc libcutils libm libuclibcrpc libselinux
LOCAL_REQUIRED_MODULES := passwd passwd_recovery
LOCAL_ADDITIONAL_DEPENDENCIES := $(busybox_prepare_minimal)
$(info "add console passwd protect end")
include $(BUILD_EXECUTABLE)

include $(CLEAR_VARS)
LOCAL_MODULE := passwd
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_OUT)/etc/
LOCAL_MODULE_TAGS := optional
LOCAL_SRC_FILES := ./etc/$(LOCAL_MODULE)
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := passwd_recovery
LOCAL_MODULE_STEM := passwd
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_RECOVERY_ROOT_OUT)/etc/
LOCAL_MODULE_TAGS := optional
LOCAL_SRC_FILES := ./etc/$(LOCAL_MODULE)
include $(BUILD_PREBUILT)

