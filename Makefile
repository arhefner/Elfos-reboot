# Elfos-reboot - warm-reboot an Elf/OS system, optionally from another unit.
#
# Needs Asm/02 and Link/02. "make" assembles src/reboot.asm and links
# the program as ./reboot.elfos, an Elf/OS executable.

ASM     ?= /opt/elfc/asm02
LINK    ?= /opt/elfc/link02

ASMFLAGS ?= -L
LFLAGS   ?= -e

MODULES = reboot

PRGS = $(patsubst %,src/%.prg,$(MODULES))

HEADERS = src/include/bios.inc src/include/kernel.inc

.PHONY: all clean

all: reboot.elfos

reboot.elfos: $(PRGS)
	$(LINK) $(LFLAGS) -o reboot.elfos $(PRGS)
	rm -f reboot.lkb

src/%.prg: src/%.asm $(HEADERS)
	cd src && $(ASM) $(ASMFLAGS) $*.asm

clean:
	rm -f reboot.elfos reboot.lkb
	rm -f src/*.prg src/*.lst src/*.build
