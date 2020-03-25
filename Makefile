# Copyright 2019 SiFive, Inc #
# SPDX-License-Identifier: Apache-2.0 #

# Provide a default for no verbose output
HIDE ?= @

PROGRAM ?= example-freertos-blinky-systemview

OBJ_DIR ?= ./$(CONFIGURATION)/build

C_SOURCES = $(wildcard *.c)

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
# SEGGER SystemView 
# ----------------------------------------------------------------------
SYSTEMVIEW_SOURCE_PATH ?= ../../SEGGER_SystemView-metal
SEGGER_SYSTEMVIEW_DIR = $(abspath $(SYSTEMVIEW_SOURCE_PATH))
#     Include SEGGER SystemView source
include $(SYSTEMVIEW_SOURCE_PATH)/scripts/SystemView.mk

MAKE_CONFIG += 	freeRTOS.define.configUSE_SEGGER_SYSTEMVIEW = 1 \
				freeRTOS.define.SYSVIEW_RECORD_ENTER_ISR = SEGGER_SYSVIEW_RecordEnterISR \
				freeRTOS.define.SYSVIEW_RECORD_EXIT_ISR = SEGGER_SYSVIEW_RecordExitISR \
				freeRTOS.define.SYSVIEW_RECORD_EXIT_ISR_TO_SCHEDULER = SEGGER_SYSVIEW_RecordEnterISR

override CFLAGS += $(foreach dir,$(SEGGER_SYSTEMVIEW_INCLUDES),-I $(dir))

override LDLIBS += -lSystemView
override LDFLAGS += -L$(join $(abspath  $(BUILD_DIRECTORIES)),/SystemView/lib)

# ----------------------------------------------------------------------
# Add custom flags for FreeRTOS
# ----------------------------------------------------------------------
FREERTOS_SOURCE_PATH ?= ../../FreeRTOS-metal
FREERTOS_DIR = $(abspath $(FREERTOS_SOURCE_PATH))
include $(FREERTOS_DIR)/scripts/FreeRTOS.mk

export FREERTOS_CONFIG_DIR = $(abspath ./)
MAKE_CONFIG += 	freeRTOS.define.portHANDLE_INTERRUPT = FreedomMetal_InterruptHandler \
				freeRTOS.define.portHANDLE_EXCEPTION = FreedomMetal_ExceptionHandler \
				freeRTOS.define.MTIME_CTRL_ADDR = 0x2000000 
ifeq ($(TARGET),sifive-hifive-unleashed)
	MAKE_CONFIG += freeRTOS.define.MTIME_RATE_HZ = 1000000
else
	MAKE_CONFIG += freeRTOS.define.MTIME_RATE_HZ = 32768
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
# Export MAKE_CONFIG string (use to pass arguments, for example to generate 
# configuration header)
# ----------------------------------------------------------------------
export MAKE_CONFIG

# ----------------------------------------------------------------------
# Export SEGGER_SYSTEMVIEW_INCLUDES which is used by FreeRTOS in case 
# SystemView is used
# ----------------------------------------------------------------------
export SEGGER_SYSTEMVIEW_INCLUDES

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
$(OBJ_DIR)/%.o: %.S libfreertos libSystemView
	$(HIDE)$(CC) -D__ASSEMBLY__ -c -o $@ $(ASFLAGS) $(CFLAGS) $<

# ----------------------------------------------------------------------
# Compile Object Files From C
# ----------------------------------------------------------------------
$(OBJ_DIR)/%.o: %.c libfreertos libSystemView
	$(HIDE)$(CC) -c -o $@ $(CFLAGS) $<

directories: $(BUILD_DIRECTORIES)

libSystemView:
	make -f Makefile -C $(SEGGER_SYSTEMVIEW_DIR) BUILD_DIR=$(join $(abspath  $(BUILD_DIRECTORIES)),/SystemView) libSystemView.a VERBOSE=$(VERBOSE)

libfreertos:
	$(info SEGGER_SYSTEMVIEW_INCLUDES=$(SEGGER_SYSTEMVIEW_INCLUDES))
	
	make -f Makefile -C $(FREERTOS_DIR) BUILD_DIR=$(join $(abspath  $(BUILD_DIRECTORIES)),/FreeRTOS) libFreeRTOS.a VERBOSE=$(VERBOSE)

$(PROGRAM): \
	directories \
	libSystemView \
	libfreertos \
	$(OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) $(_ADD_LDFLAGS) $(OBJS) $(LOADLIBES) $(LDLIBS) -o $@
	@echo

clean::
	rm -rf $(BUILD_DIRECTORIES)
	rm -f $(PROGRAM) $(PROGRAM).hex
