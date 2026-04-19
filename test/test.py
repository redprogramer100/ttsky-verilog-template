import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

CLK_FREQ  = 50_000_000
BAUDRATE  = 115_200
BIT_TICKS = CLK_FREQ // BAUDRATE  # 434 ciclos

async def uart_send_byte(dut, byte: int):
    def set_rx(val):
        current = int(dut.ui_in.value)
        dut.ui_in.value = (current & 0xFE) | (val & 1)

    set_rx(0)                                    # start bit
    await ClockCycles(dut.clk, BIT_TICKS)
    for i in range(8):
        set_rx((byte >> i) & 1)
        await ClockCycles(dut.clk, BIT_TICKS)
    set_rx(1)                                    # stop bit
    await ClockCycles(dut.clk, BIT_TICKS * 2)   # pausa extra entre bytes

async def reset_dut(dut):
    dut.ena.value    = 1
    dut.rst_n.value  = 0
    dut.ui_in.value  = 0xFF
    dut.uio_in.value = 0x00
    await ClockCycles(dut.clk, 20)
    dut.rst_n.value  = 1
    await ClockCycles(dut.clk, 20)

def get_activo(dut):
    return (int(dut.uo_out.value) >> 1) & 1

# ══════════════════════════════════════════════════════════════
# TEST 1 — Reset basico
# ══════════════════════════════════════════════════════════════
@cocotb.test()
async def test_reset(dut):
    """Despues del reset activo debe ser LOW."""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await reset_dut(dut)
    await ClockCycles(dut.clk, 20)
    assert get_activo(dut) == 0
    dut._log.info("PASS — activo=0 despues de reset")

# ══════════════════════════════════════════════════════════════
# TEST 2 — Comando R no activa timer
# ══════════════════════════════════════════════════════════════
@cocotb.test()
async def test_reset_command(dut):
    """Comando R (0x52) no activa el timer."""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await reset_dut(dut)
    await uart_send_byte(dut, 0x52)
    await ClockCycles(dut.clk, BIT_TICKS * 4)
    assert get_activo(dut) == 0
    dut._log.info("PASS — activo=0 despues de R")

# ══════════════════════════════════════════════════════════════
# TEST 3 — Comando T activa timer
# ══════════════════════════════════════════════════════════════
@cocotb.test()
async def test_start_T_command(dut):
    """Comando T con duracion > 0 debe activar el timer."""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await reset_dut(dut)

    # Enviar T + 3 bytes = 5 segundos
    # Pausa larga entre bytes para que uart_rx los capture bien
    await uart_send_byte(dut, 0x54)   # 'T'
    await uart_send_byte(dut, 0x00)   # alto
    await uart_send_byte(dut, 0x00)   # medio
    await uart_send_byte(dut, 0x05)   # bajo = 5

    # Esperar muchos ciclos para que el decoder procese
    await ClockCycles(dut.clk, BIT_TICKS * 10)

    activo = get_activo(dut)
    dut._log.info(f"activo despues de T+5 = {activo}")
    dut._log.info(f"uo_out completo = 0x{int(dut.uo_out.value):02X}")

    assert activo == 1, f"Esperaba activo=1, obtuvo {activo}"
    dut._log.info("PASS — activo=1 despues de T+5")

# ══════════════════════════════════════════════════════════════
# TEST 4 — DUT envia 0x01 por TX
# ══════════════════════════════════════════════════════════════
@cocotb.test()
async def test_uart_tx_response(dut):
    """El DUT debe enviar 0x01 por TX mientras activo."""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await reset_dut(dut)

    await uart_send_byte(dut, 0x54)
    await uart_send_byte(dut, 0x00)
    await uart_send_byte(dut, 0x00)
    await uart_send_byte(dut, 0x0A)   # 10 segundos
    await ClockCycles(dut.clk, BIT_TICKS * 10)

    assert get_activo(dut) == 1, "Timer deberia estar activo"

    # Leer byte del TX del DUT muestreando en centro de cada bit
    timeout = 500_000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if (int(dut.uo_out.value) & 1) == 0:
            break

    await ClockCycles(dut.clk, BIT_TICKS // 2)  # centro start bit
    received = 0
    for i in range(8):
        await ClockCycles(dut.clk, BIT_TICKS)
        received |= ((int(dut.uo_out.value) & 1) << i)
    await ClockCycles(dut.clk, BIT_TICKS)

    dut._log.info(f"Byte recibido: 0x{received:02X}")
    assert received == 0x01, f"Esperaba 0x01, obtuvo 0x{received:02X}"
    dut._log.info("PASS — DUT responde 0x01")

# ══════════════════════════════════════════════════════════════
# TEST 5 — R detiene timer
# ══════════════════════════════════════════════════════════════
@cocotb.test()
async def test_stop_with_R(dut):
    """R debe detener el timer."""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await reset_dut(dut)

    await uart_send_byte(dut, 0x54)
    await uart_send_byte(dut, 0x00)
    await uart_send_byte(dut, 0x00)
    await uart_send_byte(dut, 0xFF)   # 255 segundos
    await ClockCycles(dut.clk, BIT_TICKS * 10)

    assert get_activo(dut) == 1, "Timer deberia estar activo"

    await uart_send_byte(dut, 0x52)   # 'R'
    await ClockCycles(dut.clk, BIT_TICKS * 4)

    assert get_activo(dut) == 0, f"Esperaba activo=0 tras R, obtuvo {get_activo(dut)}"
    dut._log.info("PASS — timer detenido con R")
