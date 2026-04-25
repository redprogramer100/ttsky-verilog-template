/*
 * uart_trama_sender.v
 * Optimización Arquitectónica: Eliminación de separadores ASCII.
 * Reduce el multiplexor de 17 a 11 entradas para liberar ruteo en 1x1.
 * Formato: $ [4 bytes cnt] [4 bytes freq] [estado] [#]
 */

`default_nettype none

module uart_trama_sender #(
    parameter CLK_FREQ = 50000000,
    parameter BAUDRATE = 115200
)(
    input  wire        clk_i,
    input  wire        reset_i,
    input  wire [31:0] contador1_i,
    input  wire [31:0] frecuencia1_i,
    input  wire [7:0]  estado_i,
    input  wire [7:0]  fin_i,
    input  wire        Enviando_i,
    input  wire        listo_cnt1_i,
    input  wire        listo_freq1_i,
    output wire        tx_o,
    output reg         trama_ok_o
);

    reg        tx_valid;
    reg [7:0]  tx_data;
    wire       tx_ready, tx_done;

    // Transmisor UART
    uart_tx #(.CLK_FREQ(CLK_FREQ), .BAUDRATE(BAUDRATE)) u_tx (
        .clk_i(clk_i), .reset_i(reset_i), .data_i(tx_data),
        .valid_i(tx_valid), .ready_o(tx_ready), .tx_done_o(tx_done), .tx_o(tx_o)
    );

    localparam S_IDLE = 2'd0, S_SEND = 2'd1, S_WAIT = 2'd2, S_DONE = 2'd3;
    reg [1:0] state;
    reg [3:0] byte_idx; // 4 bits bastan para contar hasta 11
    
    reg prev_listo;
    wire listo_now = listo_cnt1_i & listo_freq1_i;
    wire listo_rise = listo_now & ~prev_listo;
    reg trama_enviada;

    // Multiplexor Combinacional Reducido (Cero memoria, puro ruteo directo)
    reg [7:0] current_byte;
    always @(*) begin
        case (byte_idx)
            4'd0:  current_byte = 8'h24; // '$' (Cabecera)
            4'd1:  current_byte = contador1_i[31:24];
            4'd2:  current_byte = contador1_i[23:16];
            4'd3:  current_byte = contador1_i[15:8];
            4'd4:  current_byte = contador1_i[7:0];
            4'd5:  current_byte = frecuencia1_i[31:24];
            4'd6:  current_byte = frecuencia1_i[23:16];
            4'd7:  current_byte = frecuencia1_i[15:8];
            4'd8:  current_byte = frecuencia1_i[7:0];
            4'd9:  current_byte = estado_i;
            4'd10: current_byte = fin_i;    // '#' (Fin)
            default: current_byte = 8'h00;
        endcase
    end

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            state <= S_IDLE; byte_idx <= 4'd0; tx_valid <= 1'b0;
            tx_data <= 8'd0; trama_ok_o <= 1'b0; trama_enviada <= 1'b0; prev_listo <= 1'b0;
        end else begin
            prev_listo <= listo_now;
            tx_valid   <= 1'b0;
            trama_ok_o <= 1'b0;
            if (Enviando_i == 1'b0) trama_enviada <= 1'b0;

            case (state)
                S_IDLE: if (Enviando_i && listo_rise && !trama_enviada) begin
                            byte_idx <= 4'd0; state <= S_SEND;
                        end
                S_SEND: if (tx_ready) begin 
                            tx_data <= current_byte; tx_valid <= 1'b1; state <= S_WAIT; 
                        end
                S_WAIT: if (tx_done) begin
                            if (byte_idx < 4'd10) begin 
                                byte_idx <= byte_idx + 4'd1; 
                                state <= S_SEND; 
                            end else state <= S_DONE;
                        end
                S_DONE: begin trama_ok_o <= 1'b1; trama_enviada <= 1'b1; state <= S_IDLE; end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule