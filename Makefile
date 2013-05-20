VERSION = 1
ARCH            = $(shell uname -m | sed s,i[3456789]86,ia32,)
DATADIR := /usr/share
LIBDIR := /usr/lib64
GNUEFIDIR ?= $(LIBDIR)/gnuefi/
CC = gcc
CFLAGS ?= -O0 -g3
BUILDFLAGS := $(CFLAGS) -fpic -Werror -Wall -Wextra -fshort-wchar \
        -fno-merge-constants -ffreestanding \
        -fno-stack-protector -fno-stack-check --std=gnu11 -DCONFIG_$(ARCH) \
        -I/usr/include/efi/ -I/usr/include/efi/$(ARCH)/ \
        -I/usr/include/efi/protocol
CCLDFLAGS       ?= -nostdlib -Wl,--warn-common \
        -Wl,--no-undefined -Wl,--fatal-warnings \
        -Wl,-shared -Wl,-Bsymbolic -L$(LIBDIR) -L$(GNUEFIDIR) \
        -Wl,--build-id=sha1 -Wl,--hash-style=sysv \
        $(GNUEFIDIR)/crt0-efi-$(ARCH).o
LD = ld
OBJCOPY = objcopy
OBJCOPY_GTE224  = $(shell expr `$(OBJCOPY) --version |grep ^"GNU objcopy" | sed 's/^.*\((.*)\|version\) //g' | cut -f1-2 -d.` \>= 2.24)

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

%.efi : %.so
ifneq ($(OBJCOPY_GTE224),1)
	$(error objcopy >= 2.24 is required)
endif
	$(OBJCOPY) -j .text -j .sdata -j .data -j .dynamic -j .dynsym \
		   -j .rel* -j .rela* -j .reloc -j .eh_frame \
		   $(FORMAT) $^ $@

%.so : %.o
	$(CC) $(CCLDFLAGS) -o $@ $^ -lefi -lgnuefi \
		$(shell $(CC) -print-libgcc-file-name) \
		-T $(GNUEFIDIR)/elf_$(ARCH)_efi.lds

%.o : %.c
	$(CC) $(BUILDFLAGS) -c -o $@ $^

clean :
	@rm -vf *.o *.so *.efi

install :
	install -D -d -m 0755 $(INSTALLROOT)/$(DATADIR)/certmule-$(VERSION)
	install -m 0644 certmule.efi $(INSTALLROOT)/$(DATADIR)/certmule-$(VERSION)/certmule.efi

GITTAG = $(VERSION)

test-archive:
	@rm -rf /tmp/certmule-$(VERSION) /tmp/certmule-$(VERSION)-tmp
	@mkdir -p /tmp/certmule-$(VERSION)-tmp
	@git archive --format=tar $(shell git branch | awk '/^*/ { print $$2 }') | ( cd /tmp/certmule-$(VERSION)-tmp/ ; tar x )
	@git diff | ( cd /tmp/certmule-$(VERSION)-tmp/ ; patch -s -p1 -b -z .gitdiff )
	@mv /tmp/certmule-$(VERSION)-tmp/ /tmp/certmule-$(VERSION)/
	@dir=$$PWD; cd /tmp; tar -c --bzip2 -f $$dir/certmule-$(VERSION).tar.bz2 certmule-$(VERSION)
	@rm -rf /tmp/certmule-$(VERSION)
	@echo "The archive is in certmule-$(VERSION).tar.bz2"

archive:
	git tag $(GITTAG) refs/heads/master
	@rm -rf /tmp/certmule-$(VERSION) /tmp/certmule-$(VERSION)-tmp
	@mkdir -p /tmp/certmule-$(VERSION)-tmp
	@git archive --format=tar $(GITTAG) | ( cd /tmp/certmule-$(VERSION)-tmp/ ; tar x )
	@mv /tmp/certmule-$(VERSION)-tmp/ /tmp/certmule-$(VERSION)/
	@dir=$$PWD; cd /tmp; tar -c --bzip2 -f $$dir/certmule-$(VERSION).tar.bz2 certmule-$(VERSION)
	@rm -rf /tmp/certmule-$(VERSION)
	@echo "The archive is in certmule-$(VERSION).tar.bz2"
