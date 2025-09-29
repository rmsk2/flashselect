# flashselect

`flashselect` autodetects all Kernel User Programs (KUPs) on a FoenixRetro Systems flash cartridge and creates a menu
from which each of the detected programs can be started. `flashselect` is intended to be stored in the first
block of the flash cartridge which guarantees that it is started at reboot or after a reset. The last menu entry
allows to exit `flashselect` and restarts SuperBASIC. When using `lsf` in DOS `flashselect` is shown as `selector`.
If `flashselect` detects no other KUP on the cartridge it simply shows a message that no programs where found and waits
for a key press. If a key is pressed `xdev` is started which in turn runs whatever is stored in onboard flash block 2.
On a system using the default flash layout this means that SuperBASIC is started.

## Bulding the program

Use `make` to build a binary called `loader.bin` which can be written to block 0 of the flash cartridge via 
[`fcart`](https://github.com/rmsk2/cartflash). Alternatively you can build `selector.pgz` via `make pgz`. This is mainly
intended for development purposes, i.e. you can test new functionality  without wearing out the flash memory in the
cart.

## Binary distribution

In the release section you will find prebuilt versions of `loader.bin` and `selector.pgz`.