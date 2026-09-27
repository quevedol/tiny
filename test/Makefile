# Makefile
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

# defaults
SIM ?= icarus
FST ?= -fst # Use more efficient FST format
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(PWD)/../src
PROJECT_SOURCES = project.v \
	accel/mac_int8.v \
	accel/mac_mmio.v \
	mem/spi_flash_read.v \
	mem/spi_mem_ctrl.v \
	mem/spi_mem_bridge.v \
	periph/uart_tx.v \
	soc/serv_soc.v \
	soc/serv_extmem_soc.v \
	cpu/serv_cpu.v \
	cpu/serv/serv_bufreg.v \
	cpu/serv/serv_bufreg2.v \
	cpu/serv/serv_alu.v \
	cpu/serv/serv_csr.v \
	cpu/serv/serv_ctrl.v \
	cpu/serv/serv_decode.v \
	cpu/serv/serv_immdec.v \
	cpu/serv/serv_mem_if.v \
	cpu/serv/serv_rf_if.v \
	cpu/serv/serv_rf_ram_if.v \
	cpu/serv/serv_rf_ram.v \
	cpu/serv/serv_state.v \
	cpu/serv/serv_debug.v \
	cpu/serv/serv_top.v \
	cpu/serv/serv_rf_top.v \
	cpu/serv/serv_aligner.v \
	cpu/serv/serv_compdec.v \
	cpu/serv/serv_synth_wrapper.v

ifneq ($(GATES),yes)

# RTL simulation:
SIM_BUILD				= sim_build/rtl
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))

else

# Gate level simulation:
SIM_BUILD				= sim_build/gl
COMPILE_ARGS    += -DGL_TEST
COMPILE_ARGS    += -DFUNCTIONAL
COMPILE_ARGS    += -DUSE_POWER_PINS
COMPILE_ARGS    += -DSIM
COMPILE_ARGS    += -DUNIT_DELAY=\#1
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v

# this gets copied in by the GDS action workflow
VERILOG_SOURCES += $(PWD)/gate_level_netlist.v

endif

# Allow sharing configuration between design and testbench via `include`:
COMPILE_ARGS 		+= -I$(SRC_DIR)

# Include the testbench sources:
VERILOG_SOURCES += $(PWD)/tb.v
TOPLEVEL = tb

# List test modules to run, separated by commas and without the .py suffix:
COCOTB_TEST_MODULES = test

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
