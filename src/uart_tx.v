module uart_tx #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUDRATE = 115200
)(
    input  wire       clk_i, reset_i,
    input  wire [7:0] data_i,
    input  wire       valid_i,
    output reg        ready_o, tx_done_o, tx_o
);
    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUDRATE;
    localparam IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;

    reg [1:0] state;
    reg [8:0] clk_cnt; // DIETA: 9 bits en vez de 16
    reg [2:0] bit_index;
    reg [7:0] data_reg;

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            state <= IDLE; tx_o <= 1'b1; ready_o <= 1'b1; tx_done_o <= 1'b0;
            clk_cnt <= 0; bit_index <= 0; data_reg <= 0;
        end else begin
            tx_done_o <= 1'b0;
            case (state)
                IDLE: begin
                    tx_o <= 1'b1; ready_o <= 1'b1;
                    if (valid_i) begin
                        data_reg <= data_i; ready_o <= 1'b0; clk_cnt <= 0; state <= START;
                    end
                end
                START: begin
                    tx_o <= 1'b0;
                    if (clk_cnt < CLKS_PER_BIT - 1) clk_cnt <= clk_cnt + 1;
                    else begin clk_cnt <= 0; bit_index <= 0; state <= DATA; end
                end
                DATA: begin
                    tx_o <= data_reg[bit_index]; 
                    if (clk_cnt < CLKS_PER_BIT - 1) clk_cnt <= clk_cnt + 1;
                    else begin
                        clk_cnt <= 0;
                        if (bit_index < 7) bit_index <= bit_index + 1;
                        else state <= STOP;
                    end
                end
                STOP: begin
                    tx_o <= 1'b1;
                    if (clk_cnt < CLKS_PER_BIT - 1) clk_cnt <= clk_cnt + 1;
                    else begin clk_cnt <= 0; tx_done_o <= 1'b1; state <= IDLE; end
                end
            endcase
        end
    end
endmodule