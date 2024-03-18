# Makefile

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# Verilog sources
VERILOG_SOURCES += $(PWD)/../../../base/reg/rtl/base_reg.v
VERILOG_SOURCES += $(PWD)/../rtl/al_n2w.v

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = al_n2w

# MODULE is the basename of the Python test file
MODULE = al_n2w_tb

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

# include waves
WAVES=1