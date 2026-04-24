# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

CLK_HZ    = 50_000_000
BAUD      = 115200
BIT_TICKS = CLK_HZ // BAUD 

async def uart_send_byte(dut, byte: int):
    def set_rx(val):
        current = int(dut.ui_in.value)
        dut.ui_in.value = (current & 0xFE) | (val & 1)

    set_rx(0) # Start bit
    await ClockCycles(dut.clk, BIT_TICKS)
    for i in range(8):
        set_rx((byte >> i) & 1)
        await ClockCycles(dut.clk, BIT_TICKS)
    set_rx(1) # Stop bit
    await ClockCycles(dut.clk, BIT_TICKS * 2) # Pausa entre bytes

def get_activo(dut):
    # uo_out[2] es el bit de activo
    return (int(dut.uo_out.value) >> 2) & 1

@cocotb.test()
async def test_project(dut):
    dut._log.info("Iniciando Simulación...")
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    # --- RESET ---
    dut.ena.value    = 1
    dut.ui_in.value  = 0xFF
    dut.uio_in.value = 0
    dut.rst_n.value  = 0
    await ClockCycles(dut.clk, 100)
    dut.rst_n.value  = 1
    await ClockCycles(dut.clk, 100)

    # TEST 1: Estado inicial
    assert get_activo(dut) == 0
    dut._log.info("PASS Test 1: activo=0 tras reset")

    # TEST 2: Configurar tiempo (Comando H)
    # H 0 0 : 0 0 : 0 2  (9 caracteres)
    comando_h = "H00:00:02"
    dut._log.info(f"Enviando configuración: {comando_h}")
    for char in comando_h:
        await uart_send_byte(dut, ord(char))
    
    # ESPERA CRÍTICA: Dejamos que el parser procese el último byte 
    # y que el flag hora_cargada se asiente.
    await ClockCycles(dut.clk, 5000)

    # TEST 3: Iniciar ventana (Comando I)
    dut._log.info("Enviando comando de inicio 'I'...")
    await uart_send_byte(dut, ord('I'))
    
    # Esperamos a que la FSM detecte el pulso de inicio
    await ClockCycles(dut.clk, 5000)

    activo = get_activo(dut)
    uo = int(dut.uo_out.value)
    dut._log.info(f"uo_out=0x{uo:02X} | bit_activo={activo}")
    
    assert activo == 1, f"Error: activo debe ser 1 tras comando H e I. Obtuvo {activo}"
    dut._log.info("PASS Test 3: timer activo")

    # TEST 4: Detener (Comando R)
    dut._log.info("Deteniendo con 'R'...")
    await uart_send_byte(dut, ord('R'))
    await ClockCycles(dut.clk, 5000)
    assert get_activo(dut) == 0
    dut._log.info("PASS Test 4: R detiene timer")

    dut._log.info("Todos los tests PASARON!")