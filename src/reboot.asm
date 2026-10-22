;
; reboot.asm - warm-reboot an Elf/OS system
;
; Usage: reboot [unit]
;
; Restarts the system from block device <unit> (0-7), by default unit 0,
; the only unit Elf/OS currently boots from.
;
; It does what a BIOS's disk boot does -- read sector 0 to 0100h, set up
; a small stack at 00FFh, and jump to 0106h with the unit in R8.1 --
; rather than calling f_boot, which always boots the BIOS's own default
; disk and has no way to be told a unit. Doing the read here needs only
; D_IDEREAD, the kernel's passthrough to f_ideread (so a loaded disk
; driver that hooks it is honored), the same call the kernel itself
; uses for every sector.
;
; It boots whatever the unit's sector 0 holds, as a BIOS would: an
; Elf/OS disk, an ELF-DOS disk, or any other boot sector. Two checks
; turn a hopeless case into a message instead of a jump into garbage:
; sector 0 must not be blank (all 00h or all FFh), and if it is ELF-DOS's
; MBR (the 'MBR' signature at bytes 0-2), LBA 1 must carry a kernel
; ('KRN', the header ELF-DOS's SYS writes). Sector 0 is read into this
; program's own buffer first and only copied to 0100h once it checks out.
;
; Whether the boot loader then loads its kernel from the same unit is up
; to the loader: one that honors R8.1 (ELF-DOS's MBR, Mini/DOS sys build
; 3 and later) does; one that hard-codes unit 0 loads unit 0's kernel.
;
; Registers are left as a ROM's own read of sector 0 would plausibly
; leave them -- RF = 0300h (just past the sector), R7 = R8.0 = 0 (LBA 0),
; R8.1 = E0h + unit, R2 = 00FFh, X = 2, P = 3 -- with SCRT (R4/R5) as the
; BIOS set it up at power-on. Nothing is re-probed: this is not a reset,
; so use a real reset after a program may have written wild.
;

#include    include/bios.inc
#include    include/kernel.inc

BOOT_SECTOR: equ    0100h               ; where a BIOS loads sector 0
BOOT_ENTRY:  equ    0106h               ; and enters it
BOOT_STACK:  equ    00ffh               ; the BIOS's boot-time stack


            org     2000h
start:      br      main


          ; Build information

            db      10+80h              ; month
            db      21                  ; day
            dw      2026                ; year
            dw      1                   ; build

            db      'Elf/OS reboot',0


;------------------------------------------------------------------
; Entry: RA = command tail
;------------------------------------------------------------------
main:       ldi     0                   ; default: unit 0
            plo     rb

skiplead:   lda     ra                  ; skip leading spaces
            lbz     have_unit           ; no argument
            sdi     ' '
            lbdf    skiplead

            dec     ra                  ; a single digit 0-7
            lda     ra
            smi     '0'
            lbnf    usage
            plo     rb
            smi     8
            lbdf    usage

            ldn     ra                  ; followed by the end or a space
            lbz     have_unit
            sdi     ' '
            lbnf    usage

skiptrail:  lda     ra                  ; and nothing after that
            lbz     have_unit
            sdi     ' '
            lbdf    skiptrail
            lbr     usage

have_unit:  ldi     rb_unit.1
            phi     rf
            ldi     rb_unit.0
            plo     rf
            glo     rb
            str     rf

          ; ---- LBA 1: an ELF-DOS kernel? (only matters for an ELF-DOS
          ; disk; a failed read here is not an error by itself) ----

            ldi     rb_haskrn.1         ; in memory, not a register: it has
            phi     rf                  ; to survive the next D_IDEREAD
            ldi     rb_haskrn.0
            plo     rf
            ldi     0
            str     rf
            ldi     1
            sep     scall
            dw      read_sector
            lbdf    lba1_done
            ldi     rb_buf.1
            phi     rf
            ldi     rb_buf.0
            plo     rf
            lda     rf
            xri     'K'
            lbnz    lba1_done
            lda     rf
            xri     'R'
            lbnz    lba1_done
            ldn     rf
            xri     'N'
            lbnz    lba1_done
            ldi     rb_haskrn.1
            phi     rf
            ldi     rb_haskrn.0
            plo     rf
            ldi     1
            str     rf
lba1_done:

          ; ---- LBA 0, read last: it stays in the buffer to be copied ----

            ldi     0
            sep     scall
            dw      read_sector
            lbdf    unreadable

          ; ELF-DOS's MBR? Then it needs its kernel.

            ldi     rb_buf.1
            phi     rf
            ldi     rb_buf.0
            plo     rf
            lda     rf
            xri     'M'
            lbnz    not_elfdos
            lda     rf
            xri     'B'
            lbnz    not_elfdos
            ldn     rf
            xri     'R'
            lbnz    not_elfdos
            ldi     rb_haskrn.1
            phi     rf
            ldi     rb_haskrn.0
            plo     rf
            ldn     rf
            lbz     no_kernel
            lbr     bootable

          ; Anything else boots, unless the sector is blank: all 00h
          ; or all FFh. R9.0 = OR of the bytes, R9.1 = AND.

not_elfdos: ldi     rb_buf.1
            phi     rf
            ldi     rb_buf.0
            plo     rf
            ldi     512.1
            phi     rc
            ldi     512.0
            plo     rc
            ldi     0
            plo     r9
            ldi     0ffh
            phi     r9
blank_scan: lda     rf
            str     r2
            glo     r9
            or
            plo     r9
            ghi     r9
            and
            phi     r9
            dec     rc
            glo     rc
            lbnz    blank_scan
            ghi     rc
            lbnz    blank_scan
            glo     r9
            lbz     no_boot
            ghi     r9
            xri     0ffh
            lbz     no_boot

bootable:   sep     scall
            dw      o_inmsg
            db      'Rebooting from unit ',0
            sep     scall
            dw      print_unit
            sep     scall
            dw      o_inmsg
            db      '...',13,10,0

          ; ==== no kernel calls from here on ====
          ; the unit, as a BIOS passes it: drive/head bits E0h + unit

            ldi     rb_unit.1
            phi     rf
            ldi     rb_unit.0
            plo     rf
            ldn     rf
            ori     0e0h
            phi     r8

            ldi     rb_buf.1            ; copy sector 0 to 0100h
            phi     rf
            ldi     rb_buf.0
            plo     rf
            ldi     BOOT_SECTOR.1
            phi     rd
            ldi     BOOT_SECTOR.0
            plo     rd
            ldi     512.1
            phi     rc
            ldi     512.0
            plo     rc
copy:       lda     rf
            str     rd
            inc     rd
            dec     rc
            glo     rc
            lbnz    copy
            ghi     rc
            lbnz    copy

          ; as a ROM's own read leaves them: RF past the sector, LBA 0

            ldi     (BOOT_SECTOR+512).1
            phi     rf
            ldi     (BOOT_SECTOR+512).0
            plo     rf
            ldi     0
            phi     r7
            plo     r7
            plo     r8
            ldi     BOOT_STACK.1        ; the BIOS's boot-time stack
            phi     r2
            ldi     BOOT_STACK.0
            plo     r2
            sex     r2
            lbr     BOOT_ENTRY


;------------------------------------------------------------------
; read_sector: read LBA D (0 or 1) of rb_unit into rb_buf. DF=1 on error.
;------------------------------------------------------------------
read_sector: plo    r7
            ldi     0
            phi     r7
            plo     r8
            ldi     rb_unit.1
            phi     rf
            ldi     rb_unit.0
            plo     rf
            ldn     rf
            ori     0e0h
            phi     r8
            ldi     rb_buf.1
            phi     rf
            ldi     rb_buf.0
            plo     rf
            sep     scall
            dw      D_IDEREAD
            sep     sret

print_unit: ldi     rb_unit.1
            phi     rf
            ldi     rb_unit.0
            plo     rf
            ldn     rf
            adi     '0'
            sep     scall
            dw      o_type
            sep     sret

usage:      sep     scall
            dw      o_inmsg
            db      'Usage: reboot [unit 0-7]',13,10,0
            ldi     1
            sep     sret

unreadable: sep     scall
            dw      o_inmsg
            db      'Cannot read unit ',0
            sep     scall
            dw      print_unit
            sep     scall
            dw      o_inmsg
            db      '.',13,10,0
            ldi     1
            sep     sret

no_kernel:  sep     scall
            dw      o_inmsg
            db      'Unit ',0
            sep     scall
            dw      print_unit
            sep     scall
            dw      o_inmsg
            db      ' has no ELF-DOS kernel.',13,10,0
            ldi     1
            sep     sret

no_boot:    sep     scall
            dw      o_inmsg
            db      'Unit ',0
            sep     scall
            dw      print_unit
            sep     scall
            dw      o_inmsg
            db      ' has nothing to boot (sector 0 is blank).',13,10,0
            ldi     1
            sep     sret

rb_unit:    db      0
rb_haskrn:  db      0                   ; LBA 1 carries 'KRN'
rb_buf:     ds      512

            end     start
