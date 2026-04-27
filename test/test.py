import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

@cocotb.test()
async def test_completo_contador(dut):
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    BIT_PERIOD = 434 

    async def send_uart(byte):
        # Start
        dut.ui_in.value = (int(dut.ui_in.value) & 0xFE)
        await ClockCycles(dut.clk, BIT_PERIOD)
        # Data
        for i in range(8):
            val = (byte >> i) & 1
            dut.ui_in.value = (int(dut.ui_in.value) & 0xFE) | val
            await ClockCycles(dut.clk, BIT_PERIOD)
        # Stop
        dut.ui_in.value = (int(dut.ui_in.value) | 0x01)
        await ClockCycles(dut.clk, BIT_PERIOD)

    # Reset
    dut.rst_n.value = 0
    dut.ui_in.value = 0xFF
    dut.ena.value = 1
    await ClockCycles(dut.clk, 100)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 100)

    dut._log.info("Enviando H00:00:02...")
    for c in "H00:00:02":
        await send_uart(ord(c))
    
    await send_uart(ord('I'))

    # Polling de activación (Bit 2 de uo_out)
    for _ in range(200):
        if (int(dut.uo_out.value) >> 2) & 1:
            dut._log.info(">>> Sistema ACTIVO")
            break
        await ClockCycles(dut.clk, 100)

    # Polling de desactivación
    for _ in range(2000):
        if not ((int(dut.uo_out.value) >> 2) & 1):
            dut._log.info(">>> Sistema INACTIVO - PASS")
            return
        await ClockCycles(dut.clk, 100)

    raise Exception("Timeout: El sistema no terminó")