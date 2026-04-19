module uart_tx #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUDRATE = 115200
)(
    input  wire clk_i,
    input  wire reset_i,

    input  wire [7:0] data_i,
    input  wire       valid_i,

    output reg tx_o,
    output reg ready_o
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUDRATE;

    reg [31:0] clk_cnt;
    reg [3:0]  bit_idx;
    reg [9:0]  tx_shift;
    reg busy;

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            tx_o <= 1;
            ready_o <= 1;
            busy <= 0;
        end else begin

            if (!busy && valid_i) begin
                tx_shift <= {1'b1, data_i, 1'b0};
                busy <= 1;
                ready_o <= 0;
                bit_idx <= 0;
                clk_cnt <= 0;
            end

            else if (busy) begin
                if (clk_cnt == CLKS_PER_BIT-1) begin
                    clk_cnt <= 0;
                    tx_o <= tx_shift[bit_idx];
                    bit_idx <= bit_idx + 1;

                    if (bit_idx == 9) begin
                        busy <= 0;
                        ready_o <= 1;
                        tx_o <= 1;
                    end
                end else begin
                    clk_cnt <= clk_cnt + 1;
                end
            end
        end
    end
endmodule