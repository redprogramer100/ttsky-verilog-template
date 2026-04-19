module uart_rx #(
    parameter CLK_FREQ = 100_000,
    parameter BAUDRATE = 10_000
)(
    input  wire clk_i,
    input  wire reset_i,
    input  wire rx_i,
    output reg [7:0] data_o,
    output reg       valid_o
);
    localparam CLKS_PER_BIT = CLK_FREQ / BAUDRATE;  // = 10

    reg [31:0] clk_cnt;
    reg [3:0]  bit_idx;
    reg [7:0]  rx_shift;
    reg        busy;

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            clk_cnt  <= 0;
            bit_idx  <= 0;
            busy     <= 0;
            valid_o  <= 0;
            data_o   <= 0;
            rx_shift <= 0;
        end else begin
            valid_o <= 0;
            if (!busy && !rx_i) begin
                busy    <= 1;
                clk_cnt <= CLKS_PER_BIT / 2;
                bit_idx <= 0;
            end else if (busy) begin
                if (clk_cnt == CLKS_PER_BIT - 1) begin
                    clk_cnt <= 0;
                    if (bit_idx < 8) begin
                        rx_shift[bit_idx] <= rx_i;
                        bit_idx <= bit_idx + 1;
                    end else begin
                        data_o  <= rx_shift;
                        valid_o <= 1;
                        busy    <= 0;
                    end
                end else begin
                    clk_cnt <= clk_cnt + 1;
                end
            end
        end
    end
endmodule
