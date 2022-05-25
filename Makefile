VERSION = 1
ARCH            = $(shell uname -m | sed s,i[3456789]86,ia32,)
DATADIR := /usr/share
LIBDIR := /usr/lib64
GNUEFIDIR ?= gnu-efi/
CC = gcc
CFLAGS ?= -O0 -g3
BUILDFLAGS := $(CFLAGS) -fPIC -Werror -Wall -Wextra -fshort-wchar \
        -fno-merge-constants -ffreestanding \
        -fno-stack-protector -fno-stack-check --std=gnu11 -DCONFIG_$(ARCH) \
	-I$(GNUEFIDIR)/inc \
	-I$(GNUEFIDIR)/inc/$(ARCH) \
	-I$(GNUEFIDIR)/inc/protocol
CCLDFLAGS ?= -nostdlib -fPIC -Wl,--warn-common \
        -Wl,--no-undefined -Wl,--fatal-warnings \
        -Wl,-shared -Wl,-Bsymbolic -L$(LIBDIR) -L$(GNUEFIDIR) \
        -Wl,--build-id=sha1 -Wl,--hash-style=sysv
LD = ld
OBJCOPY = objcopy
OBJCOPY_GTE224  = $(shell expr $$($(OBJCOPY) --version |grep "^GNU objcopy" | sed 's/^.*\((.*)\|version\) //g' | cut -f1-2 -d.) \>= 2.24)

dbsize = \
	$(if $(filter-out undefined,$(origin VENDOR_DB_FILE)),$(shell /usr/bin/stat --printf="%s" $(VENDOR_DB_FILE)),0)

DB_ADDRESSES=$(shell objdump -h certmule.so | ./find-addresses dbsz=$(call dbsize))
DB_ADDRESS=$(word $(2), $(call DB_ADDRESSES, $(1)))

DB_SECTION_ALIGN = 512
DB_SECTION_FLAGS = alloc,contents,load,readonly,data
define VENDOR_DB =
	$(if $(filter-out undefined,$(origin VENDOR_DB_FILE)),\
	--set-section-alignment .db=$(DB_SECTION_ALIGN) \
	--set-section-flags .db=$(DB_SECTION_FLAGS) \
	--add-section .db="$(VENDOR_DB_FILE)" \
	--change-section-address .db=$(call DB_ADDRESS, $(1), 1),)
endef

OBJFLAGS =
SOLIBS =

ifeq ($(ARCH),x86_64)
	FORMAT = --target efi-app-$(ARCH)
	BUILDFLAGS += -mno-mmx -mno-sse -mno-red-zone -nostdinc \
		-maccumulate-outgoing-args -DEFI_FUNCTION_WRAPPER \
		-DGNU_EFI_USE_MS_ABI -I$(shell $(CC) -print-file-name=include)
endif
ifeq ($(ARCH),ia32)
	FORMAT = --target efi-app-$(ARCH)
	BUILDFLAGS += -mno-mmx -mno-sse -mno-red-zone -nostdinc \
		-maccumulate-outgoing-args -m32 \
		-I$(shell $(CC) -print-file-name=include)
endif

ifeq ($(ARCH),aarch64)
	FORMAT = -O binary
	CCLDFLAGS += -Wl,--defsym=EFI_SUBSYSTEM=0xa
	BUILDFLAGS += -ffreestanding -I$(shell $(CC) -print-file-name=include)
endif

ifeq ($(ARCH),arm)
	FORMAT = -O binary
	CCLDFLAGS += -Wl,--defsym=EFI_SUBSYSTEM=0xa
	BUILDFLAGS += -ffreestanding -I$(shell $(CC) -print-file-name=include)
endif

all : certmule.efi

certmule.so : SOLIBS=
certmule.so : SOFLAGS=
certmule.so : BUILDFLAGS+=-DVENDOR_DB
certmule.efi : OBJFLAGS = --strip-unneeded $(call VENDOR_DB, $<)
certmule.efi : SECTIONS=.text .reloc .db
certmule.efi : VENDOR_DB_FILE?=db.esl

%.efi : %.so
ifneq ($(OBJCOPY_GTE224),1)
	$(error objcopy >= 2.24 is required)
endif
	$(OBJCOPY) $(foreach section,$(SECTIONS),-j $(section) ) \
		   --file-alignment 512 --section-alignment 4096 -D \
		   $(OBJFLAGS) \
		   $(FORMAT) $^ $@

%.so : %.o
	$(CC) $(CCLDFLAGS) $(SOFLAGS) -o $@ $^ $(SOLIBS) \
		$(shell $(CC) -print-libgcc-file-name) \
		-T $(GNUEFIDIR)/gnuefi/elf_$(ARCH)_efi.lds

%.o : %.c
	$(CC) $(BUILDFLAGS) -c -o $@ $^

clean :
	@rm -vf *.o *.so *.efi

update :
	git submodule update --init --recursive

install :
	install -D -d -m 0755 $(INSTALLROOT)/$(DATADIR)/certmule-$(VERSION)
	install -m 0644 certmule.efi $(INSTALLROOT)/$(DATADIR)/certmule-$(VERSION)/certmule.efi

GITTAG = $(VERSION)

test-archive:
	@./make-archive $(if $(call get-config,certmule.origin),--origin "$(call get-config,certmule.origin)") --test "$(VERSION)"

tag:
	git tag --sign $(GITTAG) refs/heads/main
	git tag -f latest-release $(GITTAG)

archive: tag
	@./make-archive $(if $(call get-config,certmule.origin),--origin "$(call get-config,certmule.origin)") --release "$(VERSION)" "$(GITTAG)" "certmule-$(GITTAG)"
