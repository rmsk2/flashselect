RM=rm
PORT=/dev/ttyUSB0
SUDO=

BINARY=selector
FORCE=-f
PYTHON=python

ifdef WIN
RM=del
PORT=COM3
SUDO=
FORCE=
endif

LOADER=loader.bin
LOADERTMP=loader_t.bin

.PHONY: cartridge
cartridge: $(LOADER)


$(BINARY): *.asm
	64tass --nostart -o $(BINARY) main.asm

clean: 
	$(RM) $(FORCE) $(BINARY)
	$(RM) $(FORCE) $(LOADER)
	$(RM) $(FORCE) $(LOADERTMP)

upload: $(BINARY).pgz
	$(SUDO) python fnxmgr.zip --port $(PORT) --run-pgz $(BINARY).pgz


$(LOADER): $(LOADERTMP) $(BINARY) 
	$(PYTHON) pad_binary.py $(LOADERTMP) $(BINARY) $(LOADER)

$(LOADERTMP): flashloader.asm
	64tass --nostart -o $(LOADERTMP) flashloader.asm