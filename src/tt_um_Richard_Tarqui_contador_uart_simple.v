`default_nettype none

/*
 * CHIP1contador.v
 * Main controller for the measurement system.
 * It connects UART communication, the command parser, 
 * the timer, and measurement modules (counter and frequency meter).
 */

module CHIP1contador (
    input  wire clk_i,       // Main system clock
    input  wire reset_i,     // Global reset
    input  wire pulso1,      // Signal input to be measured
    input  wire RX,          // UART RX line
    output wire TX,          // UART TX line
    output wire trama_ok     // Frame transmission status pulse
);

    // =====================================================
    // UART RX MODULE
    // Receiving commands at 115200 baud
    // =====================================================
    wire [7:0] rx_data;
    wire       rx_valid;

    uart_rx #(
        .CLK_FREQ(50_000_000),
        .BAUDRATE(115200)
    ) u_rx (
        .clk_i  (clk_i),
        .reset_i(reset_i),
        .rx_i   (RX),
        .data_o (rx_data),
        .valid_o(rx_valid),
        .ready_i(1'b1)
    );

    // =====================================================
    // UART COMMAND PARSER
    // Decodes commands like 'H' (Time set), 'I' (Start), 'R' (Reset)
    // =====================================================
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
        .clk_i         (clk_i),
        .reset_i       (reset_i),
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

    // =====================================================
    // PROGRAMMABLE TIMER
    // Manages the measurement window duration
    // =====================================================
    wire enable_sys;
    wire salida_temp;

    temporizador_programable #(
        .CLK_FREQ(50_000_000)
    ) u_timer (
        .clk_i      (clk_i),
        .reset_i    (reset_i | reset_pulse),
        .start_i    (init_pulse),
        .horaLista_i(horaLista),
        .horas_i    (hora),
        .minutos_i  (min),
        .segundos_i (seg),
        .salida_o   (salida_temp),
        .activo_o   (enable_sys)
    );

    // =====================================================
    // PULSE COUNTER
    // Counts falling edges during the active window
    // =====================================================
    wire [31:0] contador1;
    wire        sin_pulso1;

    contador_pulsos u_contador1 (
        .clk_i      (clk_i),
        .reset_i    (reset_i | reset_pulse),
        .enable_i   (enable_sys),
        .P1_i       (pulso1),
        .contador_o (contador1),
        .sin_pulso_o(sin_pulso1)
    );

    // =====================================================
    // FREQUENCY METER
    // Calculates Hz using reciprocal counting technique
    // =====================================================
    wire [31:0] frecuencia1;
    wire        dato_listo1;

    frecuencimetro #(
        .CLK_FREQ(50_000_000),
        .GATE_SEC(1)
    ) u_freq1 (
        .clk_i       (clk_i),
        .reset_i     (reset_i | reset_pulse),
        .enable_i    (enable_sys),
        .pulso_i     (pulso1),
        .frecuencia_o(frecuencia1),
        .dato_listo_o(dato_listo1)
    );

    // =====================================================
    // STATUS BYTE
    // estado[7:0] = { Reserved[3:0], Active, TimeOut, Ready, Error }
    // =====================================================
    wire [7:0] estado;
    assign estado = {4'b0000, enable_sys, salida_temp,
                     horaLista, error_instruccion};

    // =====================================================
    // UART DATA FRAME SENDER
    // Transmits results: $counter/frequency/status/#/\n\r
    // =====================================================
    uart_trama_sender #(
        .CLK_FREQ(50_000_000),
        .BAUDRATE(115200)
    ) u_sender (
        .clk_i         (clk_i),
        .reset_i       (reset_i | reset_pulse),
        .contador1_i   (contador1),
        .frecuencia1_i (frecuencia1),
        .estado_i      (estado),
        .fin_i         (8'h23),         // '#' default character
        .Enviando_i    (Enviando),
        .listo_cnt1_i  (dato_listo1),   // from frequency meter
        .listo_freq1_i (dato_listo1),
        .tx_o          (TX),
        .trama_ok_o    (trama_ok)
    );

endmodule
