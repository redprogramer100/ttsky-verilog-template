<!---
This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This project implements a simple UART-controlled countdown timer running at 115200 baud (8N1).

The design is composed of four submodules:

- **uart_rx**: Receives serial data at 115200 baud and outputs a valid byte when a full frame is received.
- **cmd_decoder**: Interprets incoming bytes as commands. Supported commands are:
  - `'R'` (0x52) — Reset the timer immediately.
  - `'I'` (0x49) — Start the timer with the current duration.
  - `'T'` (0x54) followed by 3 bytes — Load a custom 24-bit countdown duration and start.
- **timer_simple**: Counts down from the loaded value using 1-second ticks generated from the 50 MHz system clock. The `activo` signal stays HIGH while counting, and goes LOW when it reaches zero.
- **uart_tx**: Continuously transmits the timer status back to the host: `0x01` while active, `0x00` when idle.

## How to test

1. Connect a USB-to-UART adapter (3.3V logic) to the Tiny Tapeout board:
   - Adapter TX → `ui_in[0]` (RX of the design)
   - Adapter RX → `uo_out[0]` (TX of the design)
2. Open a serial terminal (e.g. PuTTY, minicom, screen) at **115200 baud, 8N1, no parity**.
3. Send the byte `'I'` (0x49) to start the timer immediately. The `activo` signal on `uo_out[1]` will go HIGH.
4. Send `'T'` (0x54) followed by 3 bytes to set a custom duration, for example:
   - `0x54 0x00 0x00 0x05` = 5 seconds countdown.
5. Send `'R'` (0x52) at any time to reset the timer. `activo` goes LOW immediately.
6. Monitor `uo_out[1]` with an LED or oscilloscope to observe the timer state visually.
7. Read the UART output stream: you will receive `0x01` bytes while the timer is running and `0x00` when it has finished.

## External hardware

- **USB-to-UART adapter** with 3.3V logic levels (e.g. FTDI FT232RL, CP2102, or CH340).
- **Optional:** LED connected to `uo_out[1]` to visually monitor the `activo` signal (most Tiny Tapeout demoboards already include this).
