# Simple UART Frequency Meter & Timer

## How it works
This project integrates three main functionalities into a single ASIC chip, optimized for low area usage:

1.  **Programmable Timer:** Allows setting a countdown timer in `HH:MM:SS` format via UART. It utilizes an area-efficient cascaded counter architecture to minimize logic gate count.
2.  **High-Precision Frequency Meter:** Measures the frequency of an external signal applied to the `ui_in[1]` pin using a direct counting technique over a fixed 1-second gate time.
3.  **Pulse Counter:** Tracks the total number of falling edges detected during the measurement window.

The system is fully controlled via ASCII commands over a UART interface configured at **115200 baud**.

## UART Commands
* `Hhh:mm:ss`: Load the measurement time (e.g., `H00:01:30` for 1 minute and 30 seconds).
* `I`: Start the measurement (Initializes counting).
* `R`: Reset the system and stop any ongoing measurement.
* `E`: Enable continuous telemetry transmission (Data reporting).
* `Y`: Disable telemetry transmission.

## Telemetry Data Format
When telemetry is enabled (`E`), the chip transmits a 13-byte ASCII/Binary frame over UART (115200 baud). The data variables (Pulse Count and Frequency) are transmitted as **16-bit values** (2 bytes each, MSB first) limiting the maximum measurable value to 65,535.

**Frame Structure (13 bytes):**
1. `$` (Start of frame, ASCII 0x24)
2. Pulse Count [High Byte]
3. Pulse Count [Low Byte]
4. `/` (Separator, ASCII 0x2F)
5. Frequency (Hz) [High Byte]
6. Frequency (Hz) [Low Byte]
7. `/` (Separator, ASCII 0x2F)
8. Status Byte
9. `/` (Separator, ASCII 0x2F)
10. `#` (End character, ASCII 0x23)
11. `/` (Separator, ASCII 0x2F)
12. `\n` (Line Feed, ASCII 0x0A)
13. `\r` (Carriage Return, ASCII 0x0D)

*Note: The Status Byte indicates the current state of the measurement window and error flags.*

## How to test
1.  Connect a USB-to-Serial converter to pins `ui_in[0]` (RX) and `uo_out[0]` (TX).
2.  Configure your serial terminal to **115200 baud**.
3.  Send a time string, for example: `H00:00:10`.
4.  Send the `I` command to start. You will see the `uo_out[2]` pin go HIGH.
5.  If telemetry is enabled (`E`), you will receive 13-byte data frames containing the 16-bit pulse count and the measured frequency.

## Inputs/Outputs
* **ui_in[0]**: UART RX Input.
* **ui_in[1]**: External signal input for frequency measurement.
* **uo_out[0]**: UART TX Output.
* **uo_out[1]**: Packet OK Pulse (End of transmission indicator).
* **uo_out[2]**: System ACTIVE indicator (Measurement in progress).