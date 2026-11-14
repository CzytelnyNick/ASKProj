# Projekt 5 ASK – budowa i symulacja (GHDL)
GHDL     ?= ghdl
GHDLFLAGS = --std=08 -frelaxed

VHDL_DIR = vhdl
WORK     = work

SRCS = \
	$(VHDL_DIR)/ask_types_pkg.vhd \
	$(VHDL_DIR)/cordic_pkg.vhd \
	$(VHDL_DIR)/sin_unit.vhd \
	$(VHDL_DIR)/sqrt_unit.vhd \
	$(VHDL_DIR)/atan_unit.vhd \
	$(VHDL_DIR)/arcsin_unit.vhd \
	$(VHDL_DIR)/memory.vhd \
	$(VHDL_DIR)/math_subprogram.vhd \
	$(VHDL_DIR)/main.vhd \
	$(VHDL_DIR)/tb_main.vhd

.PHONY: all analyze elaboratesim sim clean

all: sim

analyze:
	mkdir -p $(WORK)
	$(GHDL) -a $(GHDLFLAGS) --workdir=$(WORK) $(SRCS)

elaborate: analyze
	$(GHDL) -e $(GHDLFLAGS) --workdir=$(WORK) tb_main

sim: elaborate
	$(GHDL) -r $(GHDLFLAGS) --workdir=$(WORK) tb_main --wave=tb_main.ghw

clean:
	rm -rf $(WORK) *.o *.cf tb_main.ghw e~*
