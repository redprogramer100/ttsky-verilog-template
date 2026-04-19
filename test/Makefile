SIM = icarus
TOPLEVEL_LANG = verilog

VERILOG_SOURCES += $(PWD)/tb.v
VERILOG_SOURCES += $(PWD)/../src/tt_um_Richard_Tarqui_contador_uart_simple.v
VERILOG_SOURCES += $(PWD)/../src/uart_rx.v
VERILOG_SOURCES += $(PWD)/../src/uart_tx.v
VERILOG_SOURCES += $(PWD)/../src/cmd_decoder.v
VERILOG_SOURCES += $(PWD)/../src/timer_simple.v

TOPLEVEL = tb
MODULE   = test

include $(shell cocotb-config --makefiles)/Makefile.sim
