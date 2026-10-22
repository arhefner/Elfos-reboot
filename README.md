# Elfos-reboot

A warm-reboot command for Elf/OS, working like `REBOOT` in ELF-DOS.

    reboot [unit]

Restarts the system from block device `unit` (0-7). With no argument it
boots unit 0, the only unit Elf/OS currently boots from.

It does what the BIOS does at power-on: reads sector 0 of the unit to
`0100h` and enters it at `0106h` with the unit in R8.1 (`E0h` + unit),
so it boots whatever is on that disk -- an Elf/OS disk, an ELF-DOS disk,
or any other boot sector. `f_boot` is not used because it always boots
the BIOS's default disk and cannot be given a unit.

Before jumping, two checks turn a hopeless case into a message:

- sector 0 must not be blank (all `00h` or all `FFh`);
- if sector 0 is ELF-DOS's MBR, LBA 1 must hold an ELF-DOS kernel.

Whether the boot loader then loads its kernel from the same unit is up to
the loader: ELF-DOS's MBR (and Mini/DOS `sys` build 3 and later) honor
R8.1; a loader that hard-codes unit 0 will load unit 0's kernel.

This is not a hardware reset -- nothing is re-probed. After a program may
have scribbled over memory, use the reset switch.

## Building

Needs [Asm/02](https://github.com/rileym65/Asm-02) and
[Link/02](https://github.com/rileym65/Link-02):

    make

produces `reboot.elfos`, an Elf/OS executable. Copy it to the disk's
`/bin` as `reboot`.
