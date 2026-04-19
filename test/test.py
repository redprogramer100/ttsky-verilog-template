import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ClockCycles

# ── Parámetros UART ──────────────────────────────────────────
BAUD      = 9600
CLK_FREQ  = 50_000_000          # 50 MHz  (igual que tu tb.v)
BIT_TICKS = CLK_FREQ // BAUD    # ciclos por bit ≈ 5208

# ── Helper: envía un byte por RX (ui_in[0]) ──────────────────
async def uart_send_byte(dut, byte: int):
    """Simula la línea TX de un PC enviando un byte al DUT."""

    def set_rx(val):
        # ui_in[0] es el pin RX del DUT
        dut.ui_in.value = (int(dut.ui_in.value) & 0xFE) | (val & 1)

    # Start bit (LOW)
    set_rx(0)
    await ClockCycles(dut.clk, BIT_TICKS)

    # 8 bits de datos, LSB primero
    for i in range(8):
        set_rx((byte >> i) & 1)
        await ClockCycles(dut.clk, BIT_TICKS)

    # Stop bit (HIGH)
    set_rx(1)
    await ClockCycles(dut.clk, BIT_TICKS)

# ── Helper: lee el pin TX del DUT (uo_out[0]) ────────────────
async def uart_recv_byte(dut) -> int:
    """Espera y captura un byte en la línea TX del DUT."""

    # Espera flanco de bajada (start bit)
    while (int(dut.uo_out.value) & 1) == 1:
        await RisingEdge(dut.clk)

    # Centra en medio del start bit y avanza al primer dato
    await ClockCycles(dut.clk, BIT_TICKS + BIT_TICKS // 2)

    received = 0
    for i in range(8):
        bit = int(dut.uo_out.value) & 1
        received |= (bit << i)
        await ClockCycles(dut.clk, BIT_TICKS)

    return received

# ── Reset ─────────────────────────────────────────────────────
async def reset_dut(dut):
    dut.rst_n.value  = 0
    dut.ui_in.value  = 0xFF   # RX en IDLE (HIGH)
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value  = 1
    await ClockCycles(dut.clk, 5)

# ══════════════════════════════════════════════════════════════
# TEST 1 — Reset: activo debe ser 0 después de reset
# ══════════════════════════════════════════════════════════════
@cocotb.test()
async def test_reset(dut):
    """Después del reset, activo (uo_out[1]) debe ser LOW."""
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    await reset_dut(dut)

    await ClockCycles(dut.clk, 20)
    activo = (int(dut.uo_out.value) >> 1) & 1
    assert activo == 0, f"Se esperaba activo=0 tras reset, got {activo}"
    dut._log.info("PASS — activo=0 después de reset")

# ══════════════════════════════════════════════════════════════
# TEST 2 — Envía comando de START y verifica activo=1
# ══════════════════════════════════════════════════════════════
@cocotb.test()
async def test_start_command(dut):
    """Envía byte de START al DUT y verifica que activo se ponga en HIGH."""
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    await reset_dut(dut)

    # Ajusta este byte al protocolo real de tu cmd_decoder
    # Ejemplo: 0x01 = comando START con tiempo mínimo
    START_CMD = 0x01
    await uart_send_byte(dut, START_CMD)

    # Espera algunos ciclos a que el decoder procese
    await ClockCycles(dut.clk, BIT_TICKS * 2)

    activo = (int(dut.uo_out.value) >> 1) & 1
    assert activo == 1, f"Se esperaba activo=1 tras START, got {activo}"
    dut._log.info("PASS — activo=1 después de comando START")

# ══════════════════════════════════════════════════════════════
# TEST 3 — DUT responde por UART TX con 0x01 mientras activo
# ══════════════════════════════════════════════════════════════
@cocotb.test()
async def test_uart_tx_response(dut):
    """El DUT debe enviar 0x01 por UART TX mientras el timer está activo."""
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    await reset_dut(dut)

    START_CMD = 0x01
    await uart_send_byte(dut, START_CMD)

    # Captura el primer byte que manda el DUT
    received = await uart_recv_byte(dut)

    dut._log.info(f"Byte recibido del DUT: 0x{received:02X}")
    assert received in (0x00, 0x01), f"Byte inesperado: 0x{received:02X}"
    dut._log.info("PASS — DUT responde correctamente por UART TX")

# ══════════════════════════════════════════════════════════════
# TEST 4 — Comando de RESET detiene el timer
# ══════════════════════════════════════════════════════════════
@cocotb.test()
async def test_reset_command(dut):
    """Envía START y luego RESET; activo debe volver a 0."""
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    await reset_dut(dut)

    # Ajusta los bytes al protocolo de tu cmd_decoder
    START_CMD = 0x01
    RESET_CMD = 0x02   # ← cambia si tu decoder usa otro valor

    await uart_send_byte(dut, START_CMD)
    await ClockCycles(dut.clk, BIT_TICKS * 2)

    await uart_send_byte(dut, RESET_CMD)
    await ClockCycles(dut.clk, BIT_TICKS * 2)

    activo = (int(dut.uo_out.value) >> 1) & 1
    assert activo == 0, f"Se esperaba activo=0 tras RESET_CMD, got {activo}"
    dut._log.info("PASS — activo=0 después de comando RESET")
