# UART Frequency Meter & Pulse Counter

This project implements a precision measurement system controlled via UART. It allows measuring frequency and counting pulses of an external signal during a programmable time window.

## How it works
The system waits for commands through the UART interface (115200 baud, 8N1):
1. **Time Configuration:** Send `Hhh:mm:ss` (e.g., `H00:00:10` for 10 seconds).
2. **Control:** Send `I` to start measurement and `E` to enable the result report.
3. **Processing:** During the active window, the chip counts falling edges and calculates the frequency using the *Reciprocal Counting* technique.
4. **Output:** Upon completion, it transmits a 17-byte frame with the format: `$counter/frequency/status/#/\n\r`.

## Inputs and Outputs Detailed Documentation
| Pin | Name | Type | Description |
| :--- | :--- | :--- | :--- |
| `ui_in[0]` | **RX** | Input | UART command reception (115200, 8N1). |
| `ui_in[1]` | **Signal** | Input | External digital signal to be measured. |
| `uo_out[0]` | **TX** | Output | Results and telemetry transmission. |
| `uo_out[1]` | **Active** | Output | HIGH while the measurement timer is running. |
| `uo_out[2]` | **Trama OK**| Output | Single cycle pulse when the data frame is finished sending. |
| `rst_n` | **Reset** | Input | Master hardware reset (Active LOW). |

## How to test
1. Connect a USB-to-Serial adapter (3.3V) to the corresponding pins.
2. Open a serial terminal at 115200 baud.
3. Send `H00:00:05` to program a 5-second window.
4. Send `E` to enable reporting.
5. Send `I` to start. You will see the `Active` pin turn on and receive the binary data frame after 5 seconds.
