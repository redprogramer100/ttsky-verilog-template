## How it works

This project implements a precision measurement system controlled via UART at 115200 baud (8N1). It allows measuring frequency and total pulses of an external signal during a programmable time window.

The design is composed of the following submodules:

- **uart_rx**: Receives serial data at 115200 baud and synchronizes asynchronous input to the 50 MHz clock.
- **uart_parser**: Interprets incoming bytes as commands:
  - `'R'` (0x52) — Resets the system pulse and clears programmed time.
  - `'S'` (0x53) — Clears the reset pulse.
  - `'I'` (0x49) — Starts the measurement window.
  - `'X'` (0x58) — Clears the start pulse.
  - `'E'` (0x45) — Enables telemetry frame transmission.
  - `'Y'` (0x59) — Disables telemetry frame transmission.
  - `'H'` (0x48) — Followed by `hh:mm:ss` (ASCII) to load a custom measurement duration.
- **temporizador_programable**: Generates the measurement window using 1-second ticks.
- **contador_pulsos**: Counts falling edges of the input signal on `ui_in[1]`.
- **frecuencimetro**: Calculates signal frequency using reciprocal counting with a 2-stage mathematical pipeline.
- **uart_trama_sender**: Assembles and transmits a 17-byte binary frame via UART when the measurement finishes.
- **uart_tx**: Transmits serial data at 115200 baud back to the host.

## How to test

1. Connect a USB-to-UART adapter (3.3V logic) to the Tiny Tapeout board:
   - Adapter TX → `ui_in[0]` (RX of the design)
   - Adapter RX → `uo_out[0]` (TX of the design)
2. Connect a digital signal source (0-3.3V) to `ui_in[1]`.
3. Open a serial terminal at **115200 baud, 8N1**.
4. Set the measurement duration by sending the string `H00:00:10` (for 10 seconds).
5. Send `'E'` (0x45) to enable reports and then `'I'` (0x49) to start the timer.
6. The `activo` signal on `uo_out[2]` will stay HIGH while counting.
7. Once finished, read the 17-byte binary frame received on the UART terminal:
   - Structure: `$ [4-byte counter] / [4-byte frequency] / [1-byte status] / [1-byte fin] / \n \r`.
8. Send `'R'` (0x52) at any time to reset the system.

## External hardware

- **USB-to-UART adapter** with 3.3V logic levels (e.g. FTDI FT232RL, CP2102, or CH340).
- **Digital signal source** (Function generator or MCU) connected to `ui_in[1]`.
- **Optional:** Oscilloscope to monitor the `trama_ok` pulse on `uo_out[1]`.