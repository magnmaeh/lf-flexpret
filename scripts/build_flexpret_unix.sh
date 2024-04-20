#!/usr/bin/env bash

# Project root is one up from the bin directory.
PROJECT_ROOT=$LF_BIN_DIRECTORY/..

echo "Generating a Makefile for FlexPRET in $LF_SOURCE_GEN_DIRECTORY"
echo "Current directory is $(pwd)"

# Parse filename from the src-gen directory name
# https://stackoverflow.com/questions/3162385/how-to-split-a-string-in-shell-and-get-the-last-field
LF_FILENAME=${LF_SOURCE_GEN_DIRECTORY##*/} # Get the LF filename without the .lf extension.
echo "The LF filename is $LF_FILENAME.lf."

# Copy c files into /core.
cp "$PROJECT_ROOT/platform/lf_flexpret_support.c" "$LF_SOURCE_GEN_DIRECTORY/low_level_platform/impl/src"
cp "$PROJECT_ROOT/platform/lf_atomic_irq.c" "$LF_SOURCE_GEN_DIRECTORY/low_level_platform/impl/src"

# Copy header files into /include.
cp "$PROJECT_ROOT/platform/lf_flexpret_support.h" "$LF_SOURCE_GEN_DIRECTORY/low_level_platform/api/platform"
cp "$PROJECT_ROOT/platform/low_level_platform.h" "$LF_SOURCE_GEN_DIRECTORY/low_level_platform/api"

printf '
# LF variables
LF_PROJECT_ROOT := %s
LF_SOURCE_GEN_DIRECTORY := %s
LF_FILENAME := %s

NAME = $(LF_FILENAME)

include $(FLEXPRET_ROOT_DIR)/hwconfig.mk

APP_INCS := -I$(LF_PROJECT_ROOT)/flexpret/programs/lib/include \
    -I$(LF_SOURCE_GEN_DIRECTORY)/include/ \
    -I$(LF_SOURCE_GEN_DIRECTORY)/include/api \
    -I$(LF_SOURCE_GEN_DIRECTORY)/include/core \
    -I$(LF_SOURCE_GEN_DIRECTORY)/include/core/modal_models \
    -I$(LF_SOURCE_GEN_DIRECTORY)/include/core/utils \
    -I$(LF_SOURCE_GEN_DIRECTORY)/include/core/platform \
    -I$(LF_SOURCE_GEN_DIRECTORY)/include/core/threaded \
	-I$(LF_SOURCE_GEN_DIRECTORY)/core/federated/RTI \
	-I$(LF_SOURCE_GEN_DIRECTORY)/low_level_platform/api \
	-I$(LF_SOURCE_GEN_DIRECTORY)/tag/api \
	-I$(LF_SOURCE_GEN_DIRECTORY)/logging/api \
	-I$(LF_SOURCE_GEN_DIRECTORY)/version/api \
	-I$(LF_SOURCE_GEN_DIRECTORY)/platform/api \
	-I$(LF_PROJECT_ROOT)/src

APP_DEFS := -DINITIAL_EVENT_QUEUE_SIZE=10 \
	-DINITIAL_REACT_QUEUE_SIZE=10 \
	-DNO_TTY \
	-DPLATFORM_FLEXPRET \
	-DLF_THREADED \
	-DNUMBER_OF_WORKERS=%s

GENERAL_SOURCES := \
		$(LF_SOURCE_GEN_DIRECTORY)/core/clock.c \
		$(LF_SOURCE_GEN_DIRECTORY)/core/environment.c \
		$(LF_SOURCE_GEN_DIRECTORY)/core/lf_token.c \
		$(LF_SOURCE_GEN_DIRECTORY)/core/mixed_radix.c \
		$(LF_SOURCE_GEN_DIRECTORY)/core/port.c \
		$(LF_SOURCE_GEN_DIRECTORY)/core/reactor_common.c \
		$(LF_SOURCE_GEN_DIRECTORY)/core/reactor.c \
		$(LF_SOURCE_GEN_DIRECTORY)/core/tag.c \
		$(LF_SOURCE_GEN_DIRECTORY)/core/tracepoint.c \
		$(LF_SOURCE_GEN_DIRECTORY)/$(NAME).c

UTIL_SOURCES := \
		$(LF_SOURCE_GEN_DIRECTORY)/core/utils/hashset/hashset.c \
		$(LF_SOURCE_GEN_DIRECTORY)/core/utils/hashset/hashset_itr.c \
		$(LF_SOURCE_GEN_DIRECTORY)/core/utils/lf_semaphore.c \
		$(LF_SOURCE_GEN_DIRECTORY)/core/utils/pqueue_base.c \
		$(LF_SOURCE_GEN_DIRECTORY)/core/utils/pqueue_tag.c \
		$(LF_SOURCE_GEN_DIRECTORY)/core/utils/pqueue.c \
		$(LF_SOURCE_GEN_DIRECTORY)/core/utils/util.c \
		$(LF_SOURCE_GEN_DIRECTORY)/core/utils/vector.c

THREADED_SOURCES := \
		$(LF_SOURCE_GEN_DIRECTORY)/core/threaded/reactor_threaded.c \
		$(LF_SOURCE_GEN_DIRECTORY)/core/threaded/scheduler_adaptive.c \
		$(LF_SOURCE_GEN_DIRECTORY)/core/threaded/scheduler_GEDF_NP.c \
		$(LF_SOURCE_GEN_DIRECTORY)/core/threaded/scheduler_instance.c \
		$(LF_SOURCE_GEN_DIRECTORY)/core/threaded/scheduler_NP.c \
		$(LF_SOURCE_GEN_DIRECTORY)/core/threaded/scheduler_sync_tag_advance.c \
		$(LF_SOURCE_GEN_DIRECTORY)/core/threaded/watchdog.c \

MODAL_SOURCES := \
		$(LF_SOURCE_GEN_DIRECTORY)/core/modal_models/modes.c

PLATFORM_SOURCES := \
		$(LF_SOURCE_GEN_DIRECTORY)/low_level_platform/impl/src/lf_flexpret_support.c \
		$(LF_SOURCE_GEN_DIRECTORY)/low_level_platform/impl/src/lf_atomic_irq.c

LIB_SOURCES := \
		$(LF_SOURCE_GEN_DIRECTORY)/lib/schedule.c

APP_SOURCES := \
		$(GENERAL_SOURCES) \
		$(UTIL_SOURCES) \
		$(THREADED_SOURCES) \
		$(MODAL_SOURCES) \
		$(PLATFORM_SOURCES) \
		$(LIB_SOURCES) \
		$(wildcard $(LF_SOURCE_GEN_DIRECTORY)/*.c) # FIXME: Does not handle spaces.

include $(FLEXPRET_ROOT_DIR)/Makefrag

' "$PROJECT_ROOT" "$LF_SOURCE_GEN_DIRECTORY" "$LF_FILENAME" '$(THREADS)-1' > "$LF_SOURCE_GEN_DIRECTORY/Makefile"

echo "Created $LF_SOURCE_GEN_DIRECTORY/Makefile"

cd "$LF_SOURCE_GEN_DIRECTORY"
make

echo ""
echo "**** To get simulation outputs:"
echo "cd $LF_SOURCE_GEN_DIRECTORY; fp-emu +ispm=$LF_FILENAME.mem"
echo ""
