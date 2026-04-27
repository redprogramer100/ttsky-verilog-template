`default_nettype none
module tt_um_Richard_Tarqui_contador_uart_simple (
    input  wire [7:0] ui_in, output wire [7:0] uo_out,
    input  wire [7:0] uio_in, output wire [7:0] uio_out, output wire [7:0] uio_oe,
    input  wire ena, input  wire clk, input  wire rst_n
);
    wire rst = ~rst_n;
    wire rx_input = ui_in[0];
    wire raw_signal = ui_in[1];
    wire tx_output, trama_ok_signal;

    // Reset centralizado para mejorar ruteo y área
    wire reset_pulse;
    wire global_rst = rst | reset_pulse;

    reg [2:0] signal_sync;
    always @(posedge clk) signal_sync <= {signal_sync[1:0], raw_signal};
    wire signal_clean = signal_sync[2];

    wire [7:0] rx_data;
    wire rx_valid;

    uart_rx #(.CLK_FREQ(50_000_000), .BAUDRATE(115200)) u_rx (
        .clk_i(clk), .reset_i(rst), .rx_i(rx_input), .data_o(rx_data), .valid_o(rx_valid), .ready_i(1'b1)
    );

    wire init_pulse, error_instruccion, Enviando, load_h, load_m, load_s;
    wire [7:0] parser_data;
    reg hora_cargada_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) hora_cargada_reg <= 0;
        else if (reset_pulse) hora_cargada_reg <= 0;
        else if (load_s) hora_cargada_reg <= 1;
    end

    uart_parser u_parser (
        .clk_i(clk), .reset_i(rst), .rx_data(rx_data), .rx_valid(rx_valid),
        .reset_pulse_o(reset_pulse), .init_pulse_o(init_pulse), .error_pulse_o(error_instruccion),
        .load_h_o(load_h), .load_m_o(load_m), .load_s_o(load_s), .data_o(parser_data), .Enviando_o(Enviando)
    );

    wire enable_sys, salida_temp, tick_1hz_sys;
    temporizador_programable #(.CLK_FREQ(50_000_000)) u_timer (
        .clk_i(clk), .reset_i(global_rst), .start_i(init_pulse),
        .load_h(load_h), .load_m(load_m), .load_s(load_s), .data_i(parser_data),
        .salida_o(salida_temp), .activo_o(enable_sys), .tick_1hz_o(tick_1hz_sys)
    );

    wire [15:0] contador1, frecuencia1;
    wire dato_listo1, sin_pulso1;

    contador_pulsos u_c1 (.clk_i(clk), .reset_i(global_rst), .enable_i(enable_sys), .P_clean_i(signal_clean), .contador_o(contador1), .sin_pulso_o(sin_pulso1));
    frecuencimetro u_f1 (.clk_i(clk), .reset_i(global_rst), .enable_i(enable_sys), .P_clean_i(signal_clean), .tick_1hz_i(tick_1hz_sys), .frecuencia_o(frecuencia1), .dato_listo_o(dato_listo1));

    uart_trama_sender #(.CLK_FREQ(50_000_000), .BAUDRATE(115200)) u_snd (
        .clk_i(clk), .reset_i(global_rst), .contador1_i(contador1), .frecuencia1_i(frecuencia1),
        .estado_i({4'b0, enable_sys, salida_temp, hora_cargada_reg, error_instruccion}), .fin_i(8'h23),
        .Enviando_i(Enviando), .listo_cnt1_i(dato_listo1), .listo_freq1_i(dato_listo1), .tx_o(tx_output), .trama_ok_o(trama_ok_signal)
    );

    assign uo_out = {5'b00000, enable_sys, trama_ok_signal, tx_output};
    assign uio_out = 8'b0; assign uio_oe = 8'b0;
    wire _unused = &{ena, ui_in[7:2], uio_in, 1'b0};
endmodule