SIM = icarus
TOPLEVEL_LANG = verilog

# Lista completa de archivos fuente actualizados
VERILOG_SOURCES += $(PWD)/tb.v
VERILOG_SOURCES += $(PWD)/../src/tt_um_Richard_Tarqui_contador_uart_simple.v
VERILOG_SOURCES += $(PWD)/../src/uart_rx.v
VERILOG_SOURCES += $(PWD)/../src/uart_tx.v
VERILOG_SOURCES += $(PWD)/../src/uart_parser.v
VERILOG_SOURCES += $(PWD)/../src/uart_trama_sender.v
VERILOG_SOURCES += $(PWD)/../src/temporizador_programable.v
VERILOG_SOURCES += $(PWD)/../src/contador_pulsos.v
VERILOG_SOURCES += $(PWD)/../src/frecuencimetro.v

TOPLEVEL = tb
MODULE   = test

include $(shell cocotb-config --makefiles)/Makefile.sim