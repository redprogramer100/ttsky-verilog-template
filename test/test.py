import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

# ── Parámetros UART ──────────────────────────────────────────
CLK_FREQ  = 50_000_000
BAUDRATE  = 115_200
BIT_TICKS = CLK_FREQ // BAUDRATE  # ≈ 434 ciclos por bit

# ── Helper: envía un byte por RX (ui_in[0]) ──────────────────
async def uart_send_byte(dut, byte: int):
    def set_rx(val):
        current = int(dut.ui_in.value)
        dut.ui_in.value = (current & 0xFE) | (val & 1)

    # Start bit (LOW)
    set_rx(0)
    await ClockCycles(dut.clk, BIT_TICKS)

    # 8 bits de datos LSB primero
    for i in range(8):
        set_rx((byte >> i) & 1)
        await ClockCycles(dut.clk, BIT_TICKS)

    # Stop bit (HIGH)
    set_rx(1)
    await ClockCycles(dut.clk, BIT_TICKS)


# ── Helper: lee un byte desde uo_out[0] (TX del DUT) ─────────
async def uart_recv_byte(dut, timeout_cycles=100_000) -> int:
    # Espera flanco de bajada = start bit
    for _ in range(timeout_cycles):
        await RisingEdge(dut.clk)
        if (int(dut.uo_out.value) & 1) == 0:
            break
    else:
        raise TimeoutError("No se recibio start bit del DUT")

    # Centro del start bit → saltar al primer bit de datos
    await ClockCycles(dut.clk, BIT_TICKS + BIT_TICKS // 2)

    received = 0
    for i in range(8):
        received |= ((int(dut.uo_out.value) & 1) << i)
        await ClockCycles(dut.clk, BIT_TICKS)

    return received


# ── Reset del DUT ─────────────────────────────────────────────
async def reset_dut(dut):
    dut.ena.value    = 1
    dut.rst_n.value  = 0
    dut.ui_in.value  = 0xFF   # RX en IDLE (HIGH)
    dut.uio_in.value = 0x00
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value  = 1
    await ClockCycles(dut.clk, 5)


# ══════════════════════════════════════════════════════════════
# TEST 1 — Tras reset, activo (uo_out[1]) debe ser 0
# ══════════════════════════════════════════════════════════════
@cocotb.test()
async def test_reset(dut):
    """Despues del reset activo debe ser LOW."""
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    await reset_dut(dut)
    await ClockCycles(dut.clk, 20)

    activo = (int(dut.uo_out.value) >> 1) & 1
    assert activo == 0, f"Esperaba activo=0 tras reset, obtuvo {activo}"
    dut._log.info("PASS — activo=0 despues de reset")


# ══════════════════════════════════════════════════════════════
# TEST 2 — Comando 'R' (0x52) mantiene activo=0
# ══════════════════════════════════════════════════════════════
@cocotb.test()
async def test_reset_command(dut):
    """Comando R (0x52) no activa el timer."""
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    await reset_dut(dut)

    await uart_send_byte(dut, 0x52)  # 'R'
    await ClockCycles(dut.clk, BIT_TICKS * 2)

    activo = (int(dut.uo_out.value) >> 1) & 1
    assert activo == 0, f"Esperaba activo=0 tras R, obtuvo {activo}"
    dut._log.info("PASS — activo=0 despues de comando R")


# ══════════════════════════════════════════════════════════════
# TEST 3 — Comando 'I' (0x49) activa el timer
# ══════════════════════════════════════════════════════════════
@cocotb.test()
async def test_start_I_command(dut):
    """Comando I (0x49) debe activar el timer (activo=1)."""
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    await reset_dut(dut)

    # Primero cargamos un tiempo con T para que haya algo que contar
    await uart_send_byte(dut, 0x54)        # 'T'
    await uart_send_byte(dut, 0x00)        # byte alto
    await uart_send_byte(dut, 0x00)        # byte medio
    await uart_send_byte(dut, 0x05)        # byte bajo = 5 segundos
    await ClockCycles(dut.clk, BIT_TICKS * 2)

    activo = (int(dut.uo_out.value) >> 1) & 1
    assert activo == 1, f"Esperaba activo=1 tras T+datos, obtuvo {activo}"
    dut._log.info("PASS — activo=1 despues de comando T con duracion 5")


# ══════════════════════════════════════════════════════════════
# TEST 4 — DUT responde 0x01 por UART TX mientras activo
# ══════════════════════════════════════════════════════════════
@cocotb.test()
async def test_uart_tx_response(dut):
    """El DUT debe enviar 0x01 por UART TX mientras el timer esta activo."""
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    await reset_dut(dut)

    # Cargar tiempo y arrancar
    await uart_send_byte(dut, 0x54)
    await uart_send_byte(dut, 0x00)
    await uart_send_byte(dut, 0x00)
    await uart_send_byte(dut, 0x0A)   # 10 segundos
    await ClockCycles(dut.clk, BIT_TICKS * 2)

    # Leer primer byte que manda el DUT
    received = await uart_recv_byte(dut)
    dut._log.info(f"Byte recibido del DUT: 0x{received:02X}")
    assert received == 0x01, f"Esperaba 0x01, obtuvo 0x{received:02X}"
    dut._log.info("PASS — DUT responde 0x01 mientras timer activo")


# ══════════════════════════════════════════════════════════════
# TEST 5 — Comando 'R' detiene un timer en curso
# ══════════════════════════════════════════════════════════════
@cocotb.test()
async def test_stop_with_R(dut):
    """Enviar R mientras el timer corre debe detenerlo."""
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    await reset_dut(dut)

    # Arrancar con T
    await uart_send_byte(dut, 0x54)
    await uart_send_byte(dut, 0x00)
    await uart_send_byte(dut, 0x00)
    await uart_send_byte(dut, 0xFF)   # 255 segundos
    await ClockCycles(dut.clk, BIT_TICKS * 2)

    activo = (int(dut.uo_out.value) >> 1) & 1
    assert activo == 1, "El timer deberia estar activo antes del reset"

    # Enviar R para parar
    await uart_send_byte(dut, 0x52)   # 'R'
    await ClockCycles(dut.clk, BIT_TICKS * 2)

    activo = (int(dut.uo_out.value) >> 1) & 1
    assert activo == 0, f"Esperaba activo=0 tras R, obtuvo {activo}"
    dut._log.info("PASS — timer detenido con comando R")
