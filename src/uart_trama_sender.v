`default_nettype none
module uart_trama_sender #(
    parameter CLK_FREQ = 50000000,
    parameter BAUDRATE = 115200
)(
    input  wire        clk_i,
    input  wire        reset_i,
    input  wire [15:0] contador1_i,
    input  wire [15:0] frecuencia1_i,
    input  wire [7:0]  estado_i,
    input  wire [7:0]  fin_i,
    input  wire        Enviando_i,
    input  wire        listo_cnt1_i,
    input  wire        listo_freq1_i,
    output wire        tx_o,
    output reg         trama_ok_o
);

    wire       tx_ready;
    wire       tx_done;
    reg        tx_valid;
    reg  [7:0] tx_data;

    uart_tx #(.CLK_FREQ(CLK_FREQ), .BAUDRATE(BAUDRATE)) u_tx (
        .clk_i(clk_i), .reset_i(reset_i), .data_i(tx_data),
        .valid_i(tx_valid), .ready_o(tx_ready), .tx_done_o(tx_done), .tx_o(tx_o)
    );

    // Máquina de estados reducida a 4 estados (2 bits)
    localparam S_IDLE = 2'd0, S_SEND = 2'd1, S_WAIT = 2'd2, S_DONE = 2'd3;
    reg [1:0] state;
    reg [3:0] byte_idx; // Reducido a 4 bits (cuenta hasta 15 max)
    reg prev_listo;
    
    wire listo_now = listo_cnt1_i & listo_freq1_i;
    wire listo_rise = listo_now & ~prev_listo;
    reg trama_enviada;

    // Lógica Combinacional "On-The-Fly": CERO memoria, puro cableado MUX
    reg [7:0] current_byte;
    always @(*) begin
        case(byte_idx)
            4'd0:  current_byte = 8'h24; // '$'
            4'd1:  current_byte = contador1_i[15:8];
            4'd2:  current_byte = contador1_i[7:0];
            4'd3:  current_byte = 8'h2F; // '/'
            4'd4:  current_byte = frecuencia1_i[15:8];
            4'd5:  current_byte = frecuencia1_i[7:0];
            4'd6:  current_byte = 8'h2F; // '/'
            4'd7:  current_byte = estado_i;
            4'd8:  current_byte = 8'h2F; // '/'
            4'd9:  current_byte = fin_i;
            4'd10: current_byte = 8'h2F; // '/'
            4'd11: current_byte = 8'h0A; // '\n'
            4'd12: current_byte = 8'h0D; // '\r'
            default: current_byte = 8'h00;
        endcase
    end

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            state         <= S_IDLE; 
            byte_idx      <= 4'd0; 
            tx_valid      <= 1'b0;
            tx_data       <= 8'h00; 
            trama_ok_o    <= 1'b0; 
            trama_enviada <= 1'b0; 
            prev_listo    <= 1'b0;
        end else begin
            prev_listo <= listo_now;
            tx_valid   <= 1'b0;
            trama_ok_o <= 1'b0;
            
            if (!Enviando_i) trama_enviada <= 1'b0;

            case (state)
                S_IDLE: begin
                    byte_idx <= 4'd0;
                    if (Enviando_i && listo_rise && !trama_enviada) begin
                        state <= S_SEND;
                    end
                end
                S_SEND: begin
                    if (tx_ready) begin 
                        tx_data  <= current_byte; // Toma el dato directamente de los cables
                        tx_valid <= 1'b1; 
                        state    <= S_WAIT; 
                    end
                end
                S_WAIT: begin
                    if (tx_done) begin
                        if (byte_idx < 4'd12) begin 
                            byte_idx <= byte_idx + 4'd1; 
                            state    <= S_SEND; 
                        end else begin
                            state <= S_DONE;
                        end
                    end
                end
                S_DONE: begin 
                    trama_ok_o    <= 1'b1; 
                    trama_enviada <= 1'b1; 
                    state         <= S_IDLE; 
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule