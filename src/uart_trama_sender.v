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
    localparam TRAMA_LEN = 17;
    reg [7:0] trama [0:TRAMA_LEN-1];
    reg        tx_valid;
    reg  [7:0] tx_data;
    wire       tx_ready;
    wire       tx_done;

    uart_tx #(.CLK_FREQ(CLK_FREQ), .BAUDRATE(BAUDRATE)) u_tx (
        .clk_i(clk_i), .reset_i(reset_i), .data_i(tx_data),
        .valid_i(tx_valid), .ready_o(tx_ready), .tx_done_o(tx_done), .tx_o(tx_o)
    );

    localparam S_IDLE = 3'd0, S_LOAD = 3'd1, S_SEND = 3'd2, S_WAIT = 3'd3, S_DONE = 3'd4;
    reg [2:0] state;
    reg [4:0] byte_idx;
    reg prev_listo;
    wire listo_now = listo_cnt1_i & listo_freq1_i;
    wire listo_rise = listo_now & ~prev_listo;
    reg trama_enviada;

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            state <= S_IDLE; byte_idx <= 5'd0; tx_valid <= 1'b0;
            tx_data <= 8'h00; trama_ok_o <= 1'b0; trama_enviada <= 1'b0; prev_listo <= 1'b0;
        end else begin
            prev_listo <= listo_now;
            tx_valid <= 1'b0;
            trama_ok_o <= 1'b0;
            if (Enviando_i == 1'b0) trama_enviada <= 1'b0;
            case (state)
                S_IDLE: if (Enviando_i && listo_rise && !trama_enviada) state <= S_LOAD;
                S_LOAD: begin
                    trama[0] <= 8'h24; trama[1] <= contador1_i[31:24]; trama[2] <= contador1_i[23:16];
                    trama[3] <= contador1_i[15:8]; trama[4] <= contador1_i[7:0]; trama[5] <= 8'h2F;
                    trama[6] <= frecuencia1_i[31:24]; trama[7] <= frecuencia1_i[23:16];
                    trama[8] <= frecuencia1_i[15:8]; trama[9] <= frecuencia1_i[7:0];
                    trama[10] <= 8'h2F; trama[11] <= estado_i; trama[12] <= 8'h2F;
                    trama[13] <= fin_i; trama[14] <= 8'h2F; trama[15] <= 8'h0A; trama[16] <= 8'h0D;
                    byte_idx <= 5'd0; state <= S_SEND;
                end
                S_SEND: if (tx_ready) begin tx_data <= trama[byte_idx]; tx_valid <= 1'b1; state <= S_WAIT; end
                S_WAIT: if (tx_done) begin
                    if (byte_idx < 5'd16) begin byte_idx <= byte_idx + 5'd1; state <= S_SEND; end
                    else state <= S_DONE;
                end
                S_DONE: begin trama_ok_o <= 1'b1; trama_enviada <= 1'b1; state <= S_IDLE; end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule