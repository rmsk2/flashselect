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

.PHONY: pgz
pgz: $(BINARY).pgz

$(BINARY).pgz: $(BINARY)
	$(PYTHON) make_pgz.py $(BINARY)

$(BINARY): *.asm
	64tass --nostart -o $(BINARY) main.asm

clean: 
	$(RM) $(FORCE) $(BINARY)
	$(RM) $(FORCE) $(BINARY).pgz
	$(RM) $(FORCE) $(LOADER)
	$(RM) $(FORCE) $(LOADERTMP)


$(LOADER): $(LOADERTMP) $(BINARY) 
	$(PYTHON) pad_binary.py $(LOADERTMP) $(BINARY) $(LOADER)

$(LOADERTMP): flashloader.asm
	64tass --nostart -o $(LOADERTMP) flashloader.asm