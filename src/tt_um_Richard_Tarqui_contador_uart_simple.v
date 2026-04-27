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
    wire raw_signal   = ui_in[1];   
    wire tx_output;
    wire trama_ok_signal;

    // Sincronizador Centralizado
    reg [2:0] signal_sync;
    always @(posedge clk) signal_sync <= {signal_sync[1:0], raw_signal};
    wire signal_clean = signal_sync[2];

    wire [7:0] rx_data;
    wire       rx_valid;

    uart_rx #(.CLK_FREQ(50_000_000), .BAUDRATE(115200)) u_rx (
        .clk_i(clk), .reset_i(rst), .rx_i(rx_input),
        .data_o(rx_data), .valid_o(rx_valid), .ready_i(1'b1)
    );

    wire       reset_pulse, init_pulse, error_instruccion, Enviando;
    wire       load_h, load_m, load_s;
    wire [7:0] parser_data;

    // --- FIX: Separación de Reset Asíncrono y Síncrono ---
    reg hora_cargada_reg;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            hora_cargada_reg <= 1'b0; // Reset físico (botón/encendido)
        end else begin
            if (reset_pulse) begin
                hora_cargada_reg <= 1'b0; // Reset lógico (comando UART 'R')
            end else if (load_s) begin
                hora_cargada_reg <= 1'b1; // Carga de datos
            end
        end
    end

    uart_parser u_parser (
        .clk_i(clk), .reset_i(rst), .rx_data(rx_data), .rx_valid(rx_valid),
        .reset_pulse_o(reset_pulse), .init_pulse_o(init_pulse), .error_pulse_o(error_instruccion),
        .load_h_o(load_h), .load_m_o(load_m), .load_s_o(load_s),
        .data_o(parser_data), .Enviando_o(Enviando)
    );

    wire enable_sys, salida_temp, tick_1hz_sys;

    temporizador_programable #(.CLK_FREQ(50_000_000)) u_timer (
        .clk_i(clk), .reset_i(rst | reset_pulse), .start_i(init_pulse),
        .load_h(load_h), .load_m(load_m), .load_s(load_s),
        .data_i(parser_data),
        .salida_o(salida_temp), .activo_o(enable_sys), .tick_1hz_o(tick_1hz_sys)
    );

    wire [15:0] contador1, frecuencia1;
    wire        dato_listo1, sin_pulso1;

    contador_pulsos u_contador1 (
        .clk_i(clk), .reset_i(rst | reset_pulse), .enable_i(enable_sys),
        .P_clean_i(signal_clean),
        .contador_o(contador1), .sin_pulso_o(sin_pulso1)
    );

    frecuencimetro u_freq1 (
        .clk_i(clk), .reset_i(rst | reset_pulse), .enable_i(enable_sys),
        .P_clean_i(signal_clean),
        .tick_1hz_i(tick_1hz_sys),
        .frecuencia_o(frecuencia1), .dato_listo_o(dato_listo1)
    );

    wire [7:0] estado = {4'b0000, enable_sys, salida_temp, hora_cargada_reg, error_instruccion};

    uart_trama_sender #(.CLK_FREQ(50_000_000), .BAUDRATE(115200)) u_sender (
        .clk_i(clk), .reset_i(rst | reset_pulse), .contador1_i(contador1),
        .frecuencia1_i(frecuencia1), .estado_i(estado), .fin_i(8'h23),
        .Enviando_i(Enviando), .listo_cnt1_i(dato_listo1), .listo_freq1_i(dato_listo1),
        .tx_o(tx_output), .trama_ok_o(trama_ok_signal)
    );

    assign uo_out[0] = tx_output;       
    assign uo_out[1] = trama_ok_signal; 
    assign uo_out[2] = enable_sys;      
    assign uo_out[7:3] = 5'b00000;      
    assign uio_out = 8'b00000000;
    assign uio_oe  = 8'b00000000;

    wire _unused = &{ena, ui_in[7:2], uio_in, 1'b0};

endmodule