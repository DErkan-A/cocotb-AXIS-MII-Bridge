# Copyright (c) 2016 Technische Universitaet Dresden, Germany
# Chair for VLSI-Design, Diagnostic and Architecture
# Author: Martin Zabel
# All rights reserved.

CWD=$(shell pwd)

TOPLEVEL_LANG ?=verilog

VERILOG_SOURCES =$(CWD)/../hdl/bits256_divider.v
VERILOG_SOURCES +=$(CWD)/../hdl/fifo_async_netlist.v
VERILOG_SOURCES +=$(CWD)/../hdl/ready_generator_mii.v
VERILOG_SOURCES +=$(CWD)/../hdl/wrapper.v
VERILOG_SOURCES +=$(CWD)/../Xilinx/glbl.v
COMPILE_ARGS = -y $(CWD)/../Xilinx/unisims/ -s glbl

TOPLEVEL = g40_2_mii
MODULE = 40g_to_mii_cocotb

CUSTOM_SIM_DEPS=$(CWD)/Makefile

ifneq ($(filter $(SIM),ius xcelium),)
    SIM_ARGS += -v93
endif

include $(shell cocotb-config --makefiles)/Makefile.sim
