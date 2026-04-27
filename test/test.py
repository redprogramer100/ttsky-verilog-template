import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles

@cocotb.test()
async def test_completo_contador(dut):
    # Reloj de 50MHz (Corregido 'units' a 'unit')
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    # Tiempos UART
    BIT_PERIOD = 434 # Ciclos para 115200 baud

    # NUEVA FUNCIÓN: Modifica solo el bit 0 sin romper Cocotb
    def set_rx(val):
        current = int(dut.ui_in.value)
        # current & 0xFE limpia el bit 0. (val & 1) pone el nuevo valor.
        dut.ui_in.value = (current & 0xFE) | (val & 1)

    async def send_uart(byte):
        set_rx(0) # Start bit
        await ClockCycles(dut.clk, BIT_PERIOD)
        
        for i in range(8):
            set_rx(byte >> i) # Data bits (LSB first)
            await ClockCycles(dut.clk, BIT_PERIOD)
            
        set_rx(1) # Stop bit
        await ClockCycles(dut.clk, BIT_PERIOD)

    # 1. Reset inicial
    dut.rst_n.value = 0
    dut.ui_in.value = 0xFF # RX en IDLE (todos los bits en 1)
    dut.ena.value = 1
    await ClockCycles(dut.clk, 20)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)

    # 2. Enviar H00:00:02
    for c in "H00:00:02":
        await send_uart(ord(c))
    
    await ClockCycles(dut.clk, 500)

    # 3. Enviar I (Inicio)
    await send_uart(ord('I'))

    # 4. Verificar activo (uo_out[2])
    await RisingEdge(dut.uo_out[2])
    dut._log.info("Sistema funcionando...")

    # 5. Fin del conteo
    await FallingEdge(dut.uo_out[2])
    dut._log.info("Conteo terminado.")