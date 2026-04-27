import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, ValueChange

@cocotb.test()
async def test_completo_contador(dut):
    # Reloj de 50MHz
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    BIT_PERIOD = 434 # 115200 baud

    def set_rx(val):
        current = int(dut.ui_in.value)
        dut.ui_in.value = (current & 0xFE) | (val & 1)

    async def send_uart(byte):
        set_rx(0) # Start
        await ClockCycles(dut.clk, BIT_PERIOD)
        for i in range(8):
            set_rx(byte >> i)
            await ClockCycles(dut.clk, BIT_PERIOD)
        set_rx(1) # Stop
        await ClockCycles(dut.clk, BIT_PERIOD)

    async def wait_for_bit_2(estado_esperado):
        """Espera a que uo_out[2] sea igual al estado deseado"""
        while True:
            val_uo = int(dut.uo_out.value)
            bit_2 = (val_uo >> 2) & 1
            if bit_2 == estado_esperado:
                break
            await ValueChange(dut.uo_out)

    # Reset inicial
    dut.rst_n.value = 0
    dut.ui_in.value = 0xFF
    dut.ena.value = 1
    await ClockCycles(dut.clk, 50)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 100)

    # 1. Enviar H00:00:02
    dut._log.info("Enviando comando de tiempo H00:00:02...")
    for c in "H00:00:02":
        await send_uart(ord(c))
    
    await ClockCycles(dut.clk, 1000)

    # 2. Enviar I (Inicio)
    dut._log.info("Enviando comando de inicio 'I'...")
    await send_uart(ord('I'))

    # 3. Verificar activacion
    await wait_for_bit_2(1)
    dut._log.info(">>> Sistema ACTIVO")

    # 4. Esperar finalizacion (Gracias al `ifdef esto sera rapido)
    await wait_for_bit_2(0)
    dut._log.info(">>> Sistema INACTIVO - Conteo finalizado exitosamente")

    await ClockCycles(dut.clk, 500)