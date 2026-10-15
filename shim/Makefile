# Builds libqjsshim (QuickJS + shim) as one shared library.
#
#   make                    quickjs-ng (default), no Intl
#   make VARIANT=bellard    Bellard's QuickJS with experimental Temporal/Intl
#   make test               builds and runs the C tests

VARIANT ?= ng
BUILD ?= ../build/$(VARIANT)

CFLAGS := -O2 -g -fPIC -fwrapv -Wall -Wno-sign-compare -Wno-unused-parameter -D_GNU_SOURCE

ifeq ($(VARIANT),ng)
QJS := ../vendor/quickjs-ng
QJS_SRCS := quickjs.c dtoa.c libregexp.c libunicode.c
else ifeq ($(VARIANT),bellard)
QJS := ../vendor/quickjs-bellard
CFLAGS += -DCONFIG_VERSION=\"$(shell cat $(QJS)/VERSION)\" -DCONFIG_TEMPORAL_INTL
QJS_SRCS := quickjs.c dtoa.c libregexp.c libunicode.c cutils.c
QJS_SRCS += $(addprefix intl/, intl.c locale.c locale-data.c numberformat.c collator.c \
	datetimeformat.c pluralrules.c listformat.c relativetimeformat.c displaynames.c \
	segmenter.c durationformat.c)
QJS_SRCS += $(addprefix temporal/, temporal.c instant.c duration.c plaintime.c now.c \
	plaindate.c plaindatetime.c plainyearmonth.c plainmonthday.c zoneddatetime.c \
	calendar.c timezone.c tzdata_generated.c)
else
$(error VARIANT must be ng or bellard)
endif
CFLAGS += -I$(QJS)

ifeq ($(shell uname),Darwin)
LIB := $(BUILD)/libqjsshim.dylib
LIBFLAGS := -dynamiclib -install_name @rpath/libqjsshim.dylib
else
LIB := $(BUILD)/libqjsshim.so
LIBFLAGS := -shared
endif

SRCS := qjs_shim.c $(addprefix $(QJS)/, $(QJS_SRCS))

all: $(LIB) $(BUILD)/test_shim

$(LIB): $(SRCS) qjs_shim.h
	mkdir -p $(BUILD)
	$(CC) $(CFLAGS) $(LIBFLAGS) -o $@ $(SRCS) -lm -lpthread

$(BUILD)/test_shim: test_shim.c $(LIB)
	$(CC) $(CFLAGS) -o $@ test_shim.c -L$(BUILD) -lqjsshim -Wl,-rpath,$(abspath $(BUILD))

test: all
	$(BUILD)/test_shim

# the C test linked statically with AddressSanitizer, to catch double frees
asan: $(SRCS) qjs_shim.h test_shim.c
	mkdir -p $(BUILD)
	$(CC) $(CFLAGS) -O1 -fsanitize=address -fno-omit-frame-pointer -o $(BUILD)/test_shim_asan \
		test_shim.c $(SRCS) -lm -lpthread
	$(BUILD)/test_shim_asan

clean:
	rm -rf $(BUILD)

.PHONY: all test asan clean
