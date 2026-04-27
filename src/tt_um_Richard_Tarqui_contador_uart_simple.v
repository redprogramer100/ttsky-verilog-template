`default_nettype none

module tt_um_Richard_Tarqui_contador_uart_simple (
    input  wire [7:0] ui_in,    
    output wire [7:0] uo_out,   
    input  wire [7:0] uio_in,   
    output wire [7:0] uio_out,  
    output wire [7:0] uio_oe,   
    input  wire       ena,      
    input  wire       clk,      
    input  wire       rst_n     
);

    wire rst = ~rst_n; 
    wire rx_input     = ui_in[0];   
    wire signal_input = ui_in[1];   
    wire tx_output;
    wire trama_ok_signal;

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

    wire enable_sys;
    wire salida_temp;
    wire tick_1hz_sys; // <-- NUEVO CABLE PARA EL RELOJ MAESTRO

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
        .activo_o   (enable_sys),
        .tick_1hz_o (tick_1hz_sys) // <-- CONECTAMOS SALIDA
    );

    wire [15:0] contador1;
    wire        sin_pulso1;

    contador_pulsos u_contador1 (
        .clk_i      (clk),
        .reset_i    (rst | reset_pulse),
        .enable_i   (enable_sys),
        .P1_i       (signal_input),
        .contador_o (contador1),
        .sin_pulso_o(sin_pulso1)
    );

    wire [15:0] frecuencia1;
    wire        dato_listo1;

    // Sin parámetros, ahora depende del temporizador
    frecuencimetro u_freq1 (
        .clk_i       (clk),
        .reset_i     (rst | reset_pulse),
        .enable_i    (enable_sys),
        .pulso_i     (signal_input),
        .tick_1hz_i  (tick_1hz_sys), // <-- CONECTAMOS ENTRADA
        .frecuencia_o(frecuencia1),
        .dato_listo_o(dato_listo1)
    );

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
        .fin_i         (8'h23),         
        .Enviando_i    (Enviando),
        .listo_cnt1_i  (dato_listo1),
        .listo_freq1_i (dato_listo1),
        .tx_o          (tx_output),
        .trama_ok_o    (trama_ok_signal)
    );

    assign uo_out[0] = tx_output;       
    assign uo_out[1] = trama_ok_signal; 
    assign uo_out[2] = enable_sys;      
    assign uo_out[7:3] = 5'b00000;      

    assign uio_out = 8'b00000000;
    assign uio_oe  = 8'b00000000;

    wire _unused = &{ena, ui_in[7:2], uio_in, 1'b0};

endmodule