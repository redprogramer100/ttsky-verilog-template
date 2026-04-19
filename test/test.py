# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

CLK_HZ    = 100_000
BAUD      = 10_000
BIT_TICKS = CLK_HZ // BAUD  # = 10

async def uart_send_byte(dut, byte: int):
    def set_rx(val):
        current = int(dut.ui_in.value)
        dut.ui_in.value = (current & 0xFE) | (val & 1)

    dut._log.info(f"  TX byte: 0x{byte:02X}")
    set_rx(0)
    await ClockCycles(dut.clk, BIT_TICKS)
    for i in range(8):
        set_rx((byte >> i) & 1)
        await ClockCycles(dut.clk, BIT_TICKS)
    set_rx(1)
    await ClockCycles(dut.clk, BIT_TICKS * 5)  # pausa larga

def get_activo(dut):
    return (int(dut.uo_out.value) >> 1) & 1

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value    = 1
    dut.ui_in.value  = 0xFF
    dut.uio_in.value = 0
    dut.rst_n.value  = 0
    await ClockCycles(dut.clk, 20)
    dut.rst_n.value  = 1
    await ClockCycles(dut.clk, 10)

    # TEST 1: reset -> activo=0
    assert get_activo(dut) == 0, "activo debe ser 0 tras reset"
    dut._log.info("PASS Test 1: activo=0 tras reset")

    # TEST 2: 'R' no activa timer
    await uart_send_byte(dut, 0x52)
    await ClockCycles(dut.clk, 20)
    assert get_activo(dut) == 0, "R no debe activar el timer"
    dut._log.info("PASS Test 2: R no activa timer")

    # TEST 3: 'T' + 3 bytes activa timer
    dut._log.info("Enviando T+0x00+0x00+0x05")
    await uart_send_byte(dut, 0x54)  # 'T'
    await uart_send_byte(dut, 0x00)
    await uart_send_byte(dut, 0x00)
    await uart_send_byte(dut, 0x05)
    await ClockCycles(dut.clk, 50)  # espera extra

    activo = get_activo(dut)
    uo = int(dut.uo_out.value)
    dut._log.info(f"uo_out=0x{uo:02X} activo={activo}")
    assert activo == 1, f"activo debe ser 1 tras T+5, obtuvo {activo}"
    dut._log.info("PASS Test 3: timer activo tras T+5")

    # TEST 4: 'R' detiene timer
    await uart_send_byte(dut, 0x52)
    await ClockCycles(dut.clk, 20)
    assert get_activo(dut) == 0, f"activo debe ser 0 tras R"
    dut._log.info("PASS Test 4: R detiene timer")

    dut._log.info("Todos los tests PASARON!")# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

CLK_HZ    = 100_000
BAUD      = 10_000
BIT_TICKS = CLK_HZ // BAUD  # = 10

async def uart_send_byte(dut, byte: int):
    def set_rx(val):
        current = int(dut.ui_in.value)
        dut.ui_in.value = (current & 0xFE) | (val & 1)

    dut._log.info(f"  TX byte: 0x{byte:02X}")
    set_rx(0)
    await ClockCycles(dut.clk, BIT_TICKS)
    for i in range(8):
        set_rx((byte >> i) & 1)
        await ClockCycles(dut.clk, BIT_TICKS)
    set_rx(1)
    await ClockCycles(dut.clk, BIT_TICKS * 5)  # pausa larga

def get_activo(dut):
    return (int(dut.uo_out.value) >> 1) & 1

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value    = 1
    dut.ui_in.value  = 0xFF
    dut.uio_in.value = 0
    dut.rst_n.value  = 0
    await ClockCycles(dut.clk, 20)
    dut.rst_n.value  = 1
    await ClockCycles(dut.clk, 10)

    # TEST 1: reset -> activo=0
    assert get_activo(dut) == 0, "activo debe ser 0 tras reset"
    dut._log.info("PASS Test 1: activo=0 tras reset")

    # TEST 2: 'R' no activa timer
    await uart_send_byte(dut, 0x52)
    await ClockCycles(dut.clk, 20)
    assert get_activo(dut) == 0, "R no debe activar el timer"
    dut._log.info("PASS Test 2: R no activa timer")

    # TEST 3: 'T' + 3 bytes activa timer
    dut._log.info("Enviando T+0x00+0x00+0x05")
    await uart_send_byte(dut, 0x54)  # 'T'
    await uart_send_byte(dut, 0x00)
    await uart_send_byte(dut, 0x00)
    await uart_send_byte(dut, 0x05)
    await ClockCycles(dut.clk, 50)  # espera extra

    activo = get_activo(dut)
    uo = int(dut.uo_out.value)
    dut._log.info(f"uo_out=0x{uo:02X} activo={activo}")
    assert activo == 1, f"activo debe ser 1 tras T+5, obtuvo {activo}"
    dut._log.info("PASS Test 3: timer activo tras T+5")

    # TEST 4: 'R' detiene timer
    await uart_send_byte(dut, 0x52)
    await ClockCycles(dut.clk, 20)
    assert get_activo(dut) == 0, f"activo debe ser 0 tras R"
    dut._log.info("PASS Test 4: R detiene timer")

    dut._log.info("Todos los tests PASARON!")
