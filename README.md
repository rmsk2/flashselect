# flashselect

`flashselect` autodetects all Kernel User Programs (KUPs) on a FoenixRetro Systems flash cartridge and creates a menu
from which each of the detected programs can be started. `flashselect` is intended to be stored in the first
block of the flash cartridge which guarantees that it is started at reboot or after a reset. The last menu entry
allows to exit `flashselect`and restart SuperBASIC. When using `lsf` in DOS `flashselect` is shown as `selector`.

## Bulding the program

Use `make` to build a binary called `loader.bin` which can be written to block 0 of the flash cartridge via 
[`fcart`](https://github.com/rmsk2/cartflash). Alternatively you can build `selector.pgz` via `make pgz`. This is mainly
intended for development purposes, i.e. you can test new functionality  without waring out the flash memory in the
cart.

## Binary distribution

In the release section you will find prebuilt versions of `laoder.bin` and `selector.pgz`.