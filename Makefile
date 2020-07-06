CFLAGS+=-fno-zero-initialized-in-bss

CFLAGS+=$(shell pkg-config --cflags --libs libsystemd)
LDLIBS+=$(shell pkg-config --libs libsystemd)

all: test-ima-cache-evict check

ifeq ($(strip $(QEMU_MANIPULATE_SIZE)),)
$(warning QEMU_MANIPULATE_SIZE not set; run smth like make QEMU_MANIPULATE_SIZE=268435456)
endif

test-ima-cache-evict.h:
	echo "#define QEMU_MANIPULATE_SIZE $$QEMU_MANIPULATE_SIZE" | tee  $@

test-ima-cache-evict: test-ima-cache-evict.h
