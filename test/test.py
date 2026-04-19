# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

CLK_HZ    = 100_000       # 100 KHz = mismo que el ejemplo original
BAUD      = CLK_HZ // 10  # 10000 baud, facil de simular
BIT_TICKS = CLK_HZ // BAUD  # = 10 ciclos por bit

async def uart_send_byte(dut, byte: int):
    """Envia un byte UART por ui_in[0]."""
    def set_rx(val):
        current = int(dut.ui_in.value)
        dut.ui_in.value = (current & 0xFE) | (val & 1)

    set_rx(0)  # start bit
    await ClockCycles(dut.clk, BIT_TICKS)
    for i in range(8):
        set_rx((byte >> i) & 1)
        await ClockCycles(dut.clk, BIT_TICKS)
    set_rx(1)  # stop bit
    await ClockCycles(dut.clk, BIT_TICKS * 3)  # pausa entre bytes

def get_activo(dut):
    return (int(dut.uo_out.value) >> 1) & 1

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Clock 100 KHz = 10 us por ciclo (igual que el ejemplo)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value    = 1
    dut.ui_in.value  = 0xFF   # RX idle HIGH
    dut.uio_in.value = 0
    dut.rst_n.value  = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value  = 1
    await ClockCycles(dut.clk, 5)

    # TEST 1: tras reset activo=0
    dut._log.info("Test 1: reset -> activo=0")
    assert get_activo(dut) == 0, "activo debe ser 0 tras reset"
    dut._log.info("PASS Test 1")

    # TEST 2: comando R no activa timer
    dut._log.info("Test 2: comando R -> activo=0")
    await uart_send_byte(dut, 0x52)  # 'R'
    await ClockCycles(dut.clk, BIT_TICKS * 5)
    assert get_activo(dut) == 0, "R no debe activar el timer"
    dut._log.info("PASS Test 2")

    # TEST 3: comando T activa timer
    dut._log.info("Test 3: comando T+5 -> activo=1")
    await uart_send_byte(dut, 0x54)  # 'T'
    await uart_send_byte(dut, 0x00)  # alto
    await uart_send_byte(dut, 0x00)  # medio
    await uart_send_byte(dut, 0x05)  # bajo = 5
    await ClockCycles(dut.clk, BIT_TICKS * 5)
    assert get_activo(dut) == 1, f"activo debe ser 1 tras T+5, obtuvo {get_activo(dut)}"
    dut._log.info("PASS Test 3")

    # TEST 4: comando R detiene timer
    dut._log.info("Test 4: comando R detiene timer")
    await uart_send_byte(dut, 0x52)  # 'R'
    await ClockCycles(dut.clk, BIT_TICKS * 5)
    assert get_activo(dut) == 0, f"activo debe ser 0 tras R, obtuvo {get_activo(dut)}"
    dut._log.info("PASS Test 4")

    dut._log.info("Todos los tests pasaron!")
