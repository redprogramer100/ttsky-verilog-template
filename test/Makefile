# Simulador que usaremos
SIM = icarus
TOPLEVEL_LANG = verilog

# 1. Agregamos el Testbench (tb.v) a la lista de fuentes
VERILOG_SOURCES += $(PWD)/tb.v

# 2. Lista de archivos fuente del diseño (.v)
VERILOG_SOURCES += $(PWD)/../src/tt_um_Richard_Tarqui_contador_uart_simple.v
VERILOG_SOURCES += $(PWD)/../src/uart_rx.v
VERILOG_SOURCES += $(PWD)/../src/uart_tx.v
VERILOG_SOURCES += $(PWD)/../src/uart_parser.v
VERILOG_SOURCES += $(PWD)/../src/temporizador_programable.v
VERILOG_SOURCES += $(PWD)/../src/frecuencimetro.v
VERILOG_SOURCES += $(PWD)/../src/contador_pulsos.v
VERILOG_SOURCES += $(PWD)/../src/uart_trama_sender.v

# 3. CAMBIO CLAVE: El TOPLEVEL ahora debe ser 'tb' para que use tu testbench completo
TOPLEVEL = tb

# El archivo Python que contiene los tests (test.py)
MODULE = test

# Incluir las reglas de cocotb
include $(shell cocotb-config --makefiles)/Makefile.sim