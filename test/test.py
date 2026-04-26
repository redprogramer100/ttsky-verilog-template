import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles

@cocotb.test()
async def test_completo_contador(dut):
    # Reloj de 50MHz
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())

    # Tiempos UART
    BIT_PERIOD = 434 # Ciclos para 115200 baud

    async def send_uart(byte):
        dut.ui_in[0].value = 0 # Start
        await ClockCycles(dut.clk, BIT_PERIOD)
        for i in range(8):
            dut.ui_in[0].value = (byte >> i) & 1
            await ClockCycles(dut.clk, BIT_PERIOD)
        dut.ui_in[0].value = 1 # Stop
        await ClockCycles(dut.clk, BIT_PERIOD)

    # 1. Reset
    dut.rst_n.value = 0
    dut.ui_in.value = 0xFF
    dut.ena.value = 1
    await ClockCycles(dut.clk, 20)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)

    # 2. Enviar H00:00:02
    for c in "H00:00:02":
        await send_uart(ord(c))
    
    await ClockCycles(dut.clk, 500)

    # 3. Enviar I
    await send_uart(ord('I'))

    # 4. Verificar activo (uo_out[2])
    await RisingEdge(dut.uo_out[2])
    dut._log.info("Sistema funcionando...")

    # 5. Fin
    await FallingEdge(dut.uo_out[2])
    dut._log.info("Conteo terminado.")