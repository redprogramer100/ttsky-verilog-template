import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

@cocotb.test()
async def test_completo_contador(dut):
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())
    BIT_PERIOD = 434 

    async def send_uart(byte):
        dut.ui_in.value = (int(dut.ui_in.value) & 0xFE)
        await ClockCycles(dut.clk, BIT_PERIOD)
        for i in range(8):
            val = (byte >> i) & 1
            dut.ui_in.value = (int(dut.ui_in.value) & 0xFE) | val
            await ClockCycles(dut.clk, BIT_PERIOD)
        dut.ui_in.value = (int(dut.ui_in.value) | 0x01)
        await ClockCycles(dut.clk, BIT_PERIOD)

    # Reset
    dut.rst_n.value = 0
    dut.ui_in.value = 0xFF
    await ClockCycles(dut.clk, 100)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 100)

    dut._log.info("Cargando tiempo H00:00:02...")
    for c in "H00:00:02":
        await send_uart(ord(c))
    await ClockCycles(dut.clk, 500)

    dut._log.info("Enviando Inicio 'I'...")
    await send_uart(ord('I'))

    # Polling con Debug
    for i in range(5000):
        val_uo = int(dut.uo_out.value)
        bit_active = (val_uo >> 2) & 1
        
        if i % 200 == 0:
            dut._log.info(f"Iteración {i}: Bit ACTIVO = {bit_active}")
            
        if i < 100 and bit_active == 1:
            dut._log.info(">>> SISTEMA DETECTADO COMO ACTIVO")
            
        if i > 100 and bit_active == 0:
            dut._log.info(">>> SISTEMA FINALIZADO EXITOSAMENTE")
            return
        await ClockCycles(dut.clk, 100)

    raise Exception("Timeout: El sistema no terminó el conteo.")