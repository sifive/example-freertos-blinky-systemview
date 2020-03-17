# Copyright 2019 SiFive, Inc #
# SPDX-License-Identifier: Apache-2.0 #

# Provide a default for no verbose output
HIDE ?= @

PROGRAM ?= example-freertos-blinky-systemview

OBJ_DIR ?= ./$(CONFIGURATION)/build

C_SOURCES = $(wildcard *.c)

# ----------------------------------------------------------------------
# SEGGER SystemView 
# ----------------------------------------------------------------------
SYSTEMVIEW_SOURCE_PATH ?= ../../SEGGER_SystemView-metal
#     Include SEGGER SystemView source
include $(SYSTEMVIEW_SOURCE_PATH)/SystemView.mk

_COMMON_CFLAGS  += ${SEGGER_SYSTEMVIEW_INCLUDES}
_COMMON_CFLAGS  += -DconfigUSE_SEGGER_SYSTEMVIEW=1

_COMMON_CFLAGS  += -DSYSVIEW_RECORD_ENTER_ISR=SEGGER_SYSVIEW_RecordEnterISR
_COMMON_CFLAGS  += -DSYSVIEW_RECORD_EXIT_ISR=SEGGER_SYSVIEW_RecordExitISR
_COMMON_CFLAGS  += -DSYSVIEW_RECORD_EXIT_ISR_TO_SCHEDULER=SEGGER_SYSVIEW_RecordEnterISR


#     Update our list of C source files.
C_SOURCES += ${SEGGER_SYSTEMVIEW_C_SOURCE}

# ----------------------------------------------------------------------
# Build List of Object according C/CPP/S source file list
# ----------------------------------------------------------------------
_C_OBJ_FILES   += $(C_SOURCES:%.c=${OBJ_DIR}/%.o)
_CXX_OBJ_FILES += $(CXX_SOURCES:%.cpp=${OBJ_DIR}/%.o)

_asm_s := $(filter %.s,$(S_SOURCES))
_asm_S := $(filter %.S,$(S_SOURCES))
_ASM_OBJ_FILES := $(_asm_s:%.s=${OBJ_DIR}/%.o) $(_asm_S:%.S=${OBJ_DIR}/%.o)

OBJS += ${_C_OBJ_FILES}
OBJS += ${_CXX_OBJ_FILES}
OBJS += ${_ASM_OBJ_FILES}

# ----------------------------------------------------------------------
# Add custom flags for FreeRTOS
# ----------------------------------------------------------------------
FREERTOS_SOURCE_PATH ?= ../../FreeRTOS-metal
FREERTOS_DIR = $(abspath $(FREERTOS_SOURCE_PATH))
include $(FREERTOS_DIR)/scripts/FreeRTOS.mk

export portHANDLE_INTERRUPT=FreedomMetal_InterruptHandler
export portHANDLE_EXCEPTION=FreedomMetal_ExceptionHandler
export FREERTOS_CONFIG_DIR = $(abspath ./)
export MTIME_CTRL_ADDR=0x2000000
ifeq ($(TARGET),sifive-hifive-unleashed)
        export MTIME_RATE_HZ=1000000
else
        export MTIME_RATE_HZ=32768
endif
export HEAP = 4

override CFLAGS +=      $(foreach dir,$(FREERTOS_INCLUDES),-I $(dir)) \
                                        -I $(FREERTOS_CONFIG_DIR) \
                                        -I $(join $(abspath  $(BUILD_DIRECTORIES)),/FreeRTOS/include)

override LDLIBS += -lFreeRTOS
override LDFLAGS += -L$(join $(abspath  $(BUILD_DIRECTORIES)),/FreeRTOS/lib)

# ----------------------------------------------------------------------
# Update LDLIBS
# ----------------------------------------------------------------------
FILTER_PATTERN := -Wl,--end-group
override LDLIBS := $(filter-out $(FILTER_PATTERN),$(LDLIBS)) -Wl,--end-group

ifneq ($(filter rtl,$(TARGET_TAGS)),)
override CFLAGS += -D_RTL_
endif

# ----------------------------------------------------------------------
# Add custom flags for link
# ----------------------------------------------------------------------
# Reduce default size of the stack and the heap
#
override LDFLAGS  += -Wl,--defsym,__stack_size=0x200
override LDFLAGS  += -Wl,--defsym,__heap_size=0x200

# ----------------------------------------------------------------------
# create dedicated directory for Object files
# ----------------------------------------------------------------------
BUILD_DIRECTORIES = \
        $(OBJ_DIR) 

# ----------------------------------------------------------------------
# Build rules
# ----------------------------------------------------------------------
$(BUILD_DIRECTORIES):
	mkdir -p $@

# ----------------------------------------------------------------------
# Compile Object Files From Assembly
# ----------------------------------------------------------------------
$(OBJ_DIR)/%.o: %.S
	@echo "Assemble: $<"
	$(HIDE)$(CC) -D__ASSEMBLY__ -c -o $@ $(ASFLAGS) $(CPPFLAGS) $(_COMMON_CFLAGS) $<
	@echo

# ----------------------------------------------------------------------
# Compile Object Files From C
# ----------------------------------------------------------------------
$(OBJ_DIR)/%.o: %.c
	@echo "Compile: $<"
	$(HIDE)$(CC) -c -o $@ $(CFLAGS) $(CPPFLAGS) $(CFLAGS_COMMON) $(_COMMON_CFLAGS) $<
	@echo

# ----------------------------------------------------------------------
# Compile Object Files From CPP
# ----------------------------------------------------------------------
$(OBJ_DIR)/%.o: %.cpp
	@echo "Compile: $<"
	$(HIDE)$(CXX) -c -o $@ $(CXXFLAGS) $(CPPFLAGS) $(CFLAGS_COMMON) $(_COMMON_CFLAGS) $<

directories: $(BUILD_DIRECTORIES)

libfreertos:
	make -f Makefile -C $(FREERTOS_DIR) BUILD_DIR=$(join $(abspath  $(BUILD_DIRECTORIES)),/FreeRTOS) libFreeRTOS.a VERBOSE=$(VERBOSE)

$(PROGRAM): \
	directories \
	libfreertos \
	$(OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) $(_ADD_LDFLAGS) $(OBJS) $(LOADLIBES) $(LDLIBS) -o $@
	@echo

clean::
	rm -rf $(BUILD_DIRECTORIES)
	rm -f $(PROGRAM) $(PROGRAM).hex
