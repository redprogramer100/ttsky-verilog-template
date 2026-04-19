How it works


This project implements a simple UART-controlled countdown timer. It receives commands via UART (9600 baud, 8N1) on pin ui_in[0] (RX). The incoming byte is decoded by a command interpreter (cmd_decoder) that extracts two pieces of information: whether to start the timer and the duration (up to 24 bits). Once started, the timer_simple module counts down from the given value using the system clock. While the timer is running, the activo signal is HIGH. The status is continuously transmitted back via UART TX on uo_out[0], sending 0x01 while active and 0x00 when the countdown has finished.

How to test

Connect a USB-to-UART adapter (3.3V logic) to the board: TX of adapter → ui_in[0], RX of adapter → uo_out[0].
Open a serial terminal (e.g. PuTTY, minicom, or screen) at 9600 baud, 8N1, no parity.
Send a command byte that encodes start=1 and a desired countdown duration. The timer will begin immediately.
Observe uo_out[1] (the activo signal) go HIGH on the board LED — it will go LOW when the countdown expires.
Read the UART RX stream in the terminal: you will see 0x01 bytes while the timer runs and 0x00 once it finishes.
To reset the timer, send the reset command byte and assert rst_n LOW momentarily if needed.


External hardware

USB-to-UART adapter (3.3V logic level, e.g. FTDI FT232RL or CP2102) — required to send commands and receive status over serial.
Optional: an LED on uo_out[1] to visually monitor the activo signal (many demoboards already have this).
