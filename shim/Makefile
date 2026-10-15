# Builds libqjsshim against an installed QuickJS, built with its own build:
#
#   quickjs-ng (default):
#     cmake -S quickjs -B build -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
#           -DCMAKE_INSTALL_PREFIX=<prefix> -DCMAKE_INSTALL_LIBDIR=lib
#     cmake --build build && cmake --install build
#     make QUICKJS_PREFIX=<prefix>
#
#   Bellard's QuickJS (experimental Temporal/Intl):
#     make -C quickjs CC="cc -fPIC" QJSC_CC=cc install PREFIX=<prefix>
#     make VARIANT=bellard QUICKJS_PREFIX=<prefix>
#
# A static QuickJS (lib*.a, built position independent) is linked into
# libqjsshim, so the one library carries the QuickJS its header describes.
# Without one, it links the shared library (e.g. Homebrew's quickjs-ng).
#
#   make test    builds and runs the C tests
#   make asan    the same tests under AddressSanitizer

VARIANT ?= ng
BUILD ?= ../build/$(VARIANT)

UNAME := $(shell uname)
ifeq ($(UNAME),Darwin)
QUICKJS_PREFIX ?= $(or $(shell brew --prefix quickjs-ng 2>/dev/null),/usr/local)
LIB := $(BUILD)/libqjsshim.dylib
LIBFLAGS := -dynamiclib -install_name @rpath/libqjsshim.dylib
SYSLIBS := -lm -lpthread
else
QUICKJS_PREFIX ?= /usr/local
LIB := $(BUILD)/libqjsshim.so
LIBFLAGS := -shared
SYSLIBS := -lm -lpthread -ldl
endif

ifeq ($(VARIANT),ng)
QUICKJS_INCLUDE ?= $(QUICKJS_PREFIX)/include
QUICKJS_LIBDIR ?= $(QUICKJS_PREFIX)/lib
QUICKJS_LIB ?= qjs
else ifeq ($(VARIANT),bellard)
QUICKJS_INCLUDE ?= $(QUICKJS_PREFIX)/include/quickjs
QUICKJS_LIBDIR ?= $(QUICKJS_PREFIX)/lib/quickjs
QUICKJS_LIB ?= quickjs
# must match how Bellard's library was built; its default has Temporal/Intl
INTL ?= y
else
$(error VARIANT must be ng or bellard)
endif

CFLAGS := -O2 -g -fPIC -Wall -Wno-sign-compare -Wno-unused-parameter -D_GNU_SOURCE -I$(QUICKJS_INCLUDE)
ifeq ($(INTL),y)
CFLAGS += -DCONFIG_TEMPORAL_INTL
endif

STATIC := $(wildcard $(QUICKJS_LIBDIR)/lib$(QUICKJS_LIB).a)
ifneq ($(STATIC),)
QUICKJS := $(STATIC)
else
QUICKJS := -L$(QUICKJS_LIBDIR) -l$(QUICKJS_LIB) -Wl,-rpath,$(QUICKJS_LIBDIR)
endif

all: $(LIB) $(BUILD)/test_shim

$(LIB): qjs_shim.c qjs_shim.h
	@test -f $(QUICKJS_INCLUDE)/quickjs.h || (echo "no quickjs.h in $(QUICKJS_INCLUDE); set QUICKJS_PREFIX" && exit 1)
	mkdir -p $(BUILD)
	$(CC) $(CFLAGS) $(LIBFLAGS) -o $@ qjs_shim.c $(QUICKJS) $(SYSLIBS)

$(BUILD)/test_shim: test_shim.c $(LIB)
	$(CC) $(CFLAGS) -o $@ test_shim.c -L$(BUILD) -lqjsshim -Wl,-rpath,$(abspath $(BUILD))

test: all
	$(BUILD)/test_shim

# The C test and the shim with AddressSanitizer, linked with QuickJS directly
asan: qjs_shim.c qjs_shim.h test_shim.c
	mkdir -p $(BUILD)
	$(CC) $(CFLAGS) -O1 -fsanitize=address -fno-omit-frame-pointer -o $(BUILD)/test_shim_asan \
		test_shim.c qjs_shim.c $(QUICKJS) $(SYSLIBS)
	$(BUILD)/test_shim_asan

clean:
	rm -rf $(BUILD)

.PHONY: all test asan clean
