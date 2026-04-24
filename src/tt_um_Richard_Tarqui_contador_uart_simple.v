/*
 * tt_um_Richard_Tarqui_contador_uart_simple.v
 *
 * Integrated Frequency Meter & Pulse Counter for Tiny Tapeout.
 * This module contains the top-level pin mapping and the internal 
 * controller logic (formerly CHIP1contador).
 *
 * Author: Richard Alfredo Tarqui Mamani & Gustavo Ismael Chavez Mamani
 */

`default_nettype none

module tt_um_Richard_Tarqui_contador_uart_simple (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high)
    input  wire       ena,      // Design enable
    input  wire       clk,      // System clock (Default 50MHz)
    input  wire       rst_n     // Global reset (Active LOW)
);

    // ------------------------------------------------------------------------
    // INTERNAL SIGNALS & RESET LOGIC
    // ------------------------------------------------------------------------
    wire rst = ~rst_n; // Invert active-low reset for internal logic

    // Pin Assignments
    wire rx_input     = ui_in[0];   // UART RX
    wire signal_input = ui_in[1];   // External Signal to Measure
    
    wire tx_output;
    wire trama_ok_signal;

    // ------------------------------------------------------------------------
    // UART RECEIVER INSTANTIATION
    // ------------------------------------------------------------------------
    wire [7:0] rx_data;
    wire       rx_valid;

    uart_rx #(
        .CLK_FREQ(50_000_000),
        .BAUDRATE(115200)
    ) u_rx (
        .clk_i  (clk),
        .reset_i(rst),
        .rx_i   (rx_input),
        .data_o (rx_data),
        .valid_o(rx_valid),
        .ready_i(1'b1)
    );

    // ------------------------------------------------------------------------
    // COMMAND PARSER INSTANTIATION
    // Decodes commands like 'H' (Time), 'I' (Start), 'R' (Reset), 'E' (Enable)
    // ------------------------------------------------------------------------
    wire       reset_pulse;
    wire       init_pulse;
    wire       error_instruccion;
    wire       horaLista;
    wire       Enviando;
    wire [7:0] hora;
    wire [7:0] min;
    wire [7:0] seg;

    uart_parser #(
        .CLK_FREQ(50_000_000)
    ) u_parser (
        .clk_i         (clk),
        .reset_i       (rst),
        .rx_data       (rx_data),
        .rx_valid      (rx_valid),
        .reset_pulse_o (reset_pulse),
        .init_pulse_o  (init_pulse),
        .error_pulse_o (error_instruccion),
        .horaLista_o   (horaLista),
        .hora_o        (hora),
        .min_o         (min),
        .seg_o         (seg),
        .Enviando_o    (Enviando)
    );

    // ------------------------------------------------------------------------
    // PROGRAMMABLE TIMER INSTANTIATION
    // Creates the measurement window based on programmed HH:MM:SS
    // ------------------------------------------------------------------------
    wire enable_sys;
    wire salida_temp;

    temporizador_programable #(
        .CLK_FREQ(50_000_000)
    ) u_timer (
        .clk_i      (clk),
        .reset_i    (rst | reset_pulse),
        .start_i    (init_pulse),
        .horaLista_i(horaLista),
        .horas_i    (hora),
        .minutos_i  (min),
        .segundos_i (seg),
        .salida_o   (salida_temp),
        .activo_o   (enable_sys)
    );

    // ------------------------------------------------------------------------
    // PULSE COUNTER INSTANTIATION
    // Counts falling edges of 'signal_input' during 'enable_sys' window
    // ------------------------------------------------------------------------
    wire [31:0] contador1;
    wire        sin_pulso1;

    contador_pulsos u_contador1 (
        .clk_i      (clk),
        .reset_i    (rst | reset_pulse),
        .enable_i   (enable_sys),
        .P1_i       (signal_input),
        .contador_o (contador1),
        .sin_pulso_o(sin_pulso1)
    );

    // ------------------------------------------------------------------------
    // FREQUENCY METER INSTANTIATION
    // High precision frequency measurement (1s Gate)
    // ------------------------------------------------------------------------
    wire [31:0] frecuencia1;
    wire        dato_listo1;

    frecuencimetro #(
        .CLK_FREQ(50_000_000),
        .GATE_SEC(1)
    ) u_freq1 (
        .clk_i       (clk),
        .reset_i     (rst | reset_pulse),
        .enable_i    (enable_sys),
        .pulso_i     (signal_input),
        .frecuencia_o(frecuencia1),
        .dato_listo_o(dato_listo1)
    );

    // ------------------------------------------------------------------------
    // STATUS BYTE & TELEMETRY SENDER
    // ------------------------------------------------------------------------
    wire [7:0] estado = {4'b0000, enable_sys, salida_temp, horaLista, error_instruccion};

    uart_trama_sender #(
        .CLK_FREQ(50_000_000),
        .BAUDRATE(115200)
    ) u_sender (
        .clk_i         (clk),
        .reset_i       (rst | reset_pulse),
        .contador1_i   (contador1),
        .frecuencia1_i (frecuencia1),
        .estado_i      (estado),
        .fin_i         (8'h23),         // '#' character
        .Enviando_i    (Enviando),
        .listo_cnt1_i  (dato_listo1),
        .listo_freq1_i (dato_listo1),
        .tx_o          (tx_output),
        .trama_ok_o    (trama_ok_signal)
    );

    // ------------------------------------------------------------------------
    // OUTPUT PIN CONNECTIONS
    // ------------------------------------------------------------------------
    assign uo_out[0] = tx_output;        // UART TX
    assign uo_out[1] = trama_ok_signal;  // Done pulse
    assign uo_out[2] = enable_sys;      // Active measurement flag
    assign uo_out[7:3] = 5'b00000;      // Reserved

    // Tie bidirectional IOs to ground (Inputs by default)
    assign uio_out = 8'b00000000;
    assign uio_oe  = 8'b00000000;

    // Suppress unused signal warnings
    wire _unused = &{ena, ui_in[7:2], uio_in, 1'b0};

endmodule