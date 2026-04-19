import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

CLK_FREQ  = 50_000_000
BAUDRATE  = 115_200
BIT_TICKS = CLK_FREQ // BAUDRATE  # ≈ 434 ciclos por bit

async def uart_send_byte(dut, byte: int):
    def set_rx(val):
        current = int(dut.ui_in.value)
        dut.ui_in.value = (current & 0xFE) | (val & 1)

    set_rx(0)
    await ClockCycles(dut.clk, BIT_TICKS)
    for i in range(8):
        set_rx((byte >> i) & 1)
        await ClockCycles(dut.clk, BIT_TICKS)
    set_rx(1)
    await ClockCycles(dut.clk, BIT_TICKS)

async def uart_recv_byte(dut, timeout_cycles=500_000) -> int:
    for _ in range(timeout_cycles):
        await RisingEdge(dut.clk)
        if (int(dut.uo_out.value) & 1) == 0:
            break
    else:
        raise TimeoutError("No se recibio start bit del DUT")

    # Muestrear en el centro de cada bit
    await ClockCycles(dut.clk, BIT_TICKS // 2)

    received = 0
    for i in range(8):
        await ClockCycles(dut.clk, BIT_TICKS)
        received |= ((int(dut.uo_out.value) & 1) << i)

    # Esperar stop bit
    await ClockCycles(dut.clk, BIT_TICKS)
    return received

async def reset_dut(dut):
    dut.ena.value    = 1
    dut.rst_n.value  = 0
    dut.ui_in.value  = 0xFF
    dut.uio_in.value = 0x00
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value  = 1
    await ClockCycles(dut.clk, 5)

async def send_time_cmd(dut, seconds: int):
    """Envía comando T seguido de 3 bytes de duración."""
    await uart_send_byte(dut, 0x54)              # 'T'
    await uart_send_byte(dut, (seconds >> 16) & 0xFF)
    await uart_send_byte(dut, (seconds >> 8)  & 0xFF)
    await uart_send_byte(dut, (seconds)       & 0xFF)
    # Esperar suficientes ciclos para que el decoder procese el último byte
    await ClockCycles(dut.clk, BIT_TICKS * 4)

def get_activo(dut):
    return (int(dut.uo_out.value) >> 1) & 1

# ══════════════════════════════════════════════════════════════
# TEST 1 — Tras reset, activo debe ser 0
# ══════════════════════════════════════════════════════════════
@cocotb.test()
async def test_reset(dut):
    """Despues del reset activo debe ser LOW."""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await reset_dut(dut)
    await ClockCycles(dut.clk, 20)
    assert get_activo(dut) == 0, f"Esperaba activo=0 tras reset, obtuvo {get_activo(dut)}"
    dut._log.info("PASS — activo=0 despues de reset")

# ══════════════════════════════════════════════════════════════
# TEST 2 — Comando R mantiene activo=0
# ══════════════════════════════════════════════════════════════
@cocotb.test()
async def test_reset_command(dut):
    """Comando R (0x52) no activa el timer."""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await reset_dut(dut)
    await uart_send_byte(dut, 0x52)
    await ClockCycles(dut.clk, BIT_TICKS * 4)
    assert get_activo(dut) == 0, f"Esperaba activo=0 tras R, obtuvo {get_activo(dut)}"
    dut._log.info("PASS — activo=0 despues de comando R")

# ══════════════════════════════════════════════════════════════
# TEST 3 — Comando T activa el timer
# ══════════════════════════════════════════════════════════════
@cocotb.test()
async def test_start_T_command(dut):
    """Comando T con duracion > 0 debe activar el timer."""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await reset_dut(dut)
    await send_time_cmd(dut, 5)
    assert get_activo(dut) == 1, f"Esperaba activo=1 tras T+5, obtuvo {get_activo(dut)}"
    dut._log.info("PASS — activo=1 despues de comando T con duracion 5")

# ══════════════════════════════════════════════════════════════
# TEST 4 — DUT responde 0x01 por UART TX mientras activo
# ══════════════════════════════════════════════════════════════
@cocotb.test()
async def test_uart_tx_response(dut):
    """El DUT debe enviar 0x01 por UART TX mientras el timer esta activo."""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await reset_dut(dut)
    await send_time_cmd(dut, 10)
    assert get_activo(dut) == 1, "Timer deberia estar activo"
    received = await uart_recv_byte(dut)
    dut._log.info(f"Byte recibido del DUT: 0x{received:02X}")
    assert received == 0x01, f"Esperaba 0x01, obtuvo 0x{received:02X}"
    dut._log.info("PASS — DUT responde 0x01 mientras timer activo")

# ══════════════════════════════════════════════════════════════
# TEST 5 — Comando R detiene timer en curso
# ══════════════════════════════════════════════════════════════
@cocotb.test()
async def test_stop_with_R(dut):
    """Enviar R mientras el timer corre debe detenerlo."""
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await reset_dut(dut)
    await send_time_cmd(dut, 255)
    assert get_activo(dut) == 1, "Timer deberia estar activo antes del reset"
    await uart_send_byte(dut, 0x52)
    await ClockCycles(dut.clk, BIT_TICKS * 4)
    assert get_activo(dut) == 0, f"Esperaba activo=0 tras R, obtuvo {get_activo(dut)}"
    dut._log.info("PASS — timer detenido con comando R")
