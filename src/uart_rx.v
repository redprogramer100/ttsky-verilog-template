module uart_rx #(
    parameter CLK_FREQ = 100_000,
    parameter BAUDRATE = 10_000
)(
    input  wire       clk_i,
    input  wire       reset_i,
    input  wire       rx_i,
    output reg  [7:0] data_o,
    output reg        valid_o
);
    localparam CLKS_PER_BIT = CLK_FREQ / BAUDRATE;
    localparam HALF_BIT     = CLKS_PER_BIT / 2;

    localparam S_IDLE  = 2'd0;
    localparam S_START = 2'd1;
    localparam S_DATA  = 2'd2;
    localparam S_STOP  = 2'd3;

    reg [1:0]  state;
    reg [15:0] cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  shift;

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            state   <= S_IDLE;
            cnt     <= 0;
            bit_idx <= 0;
            shift   <= 0;
            data_o  <= 0;
            valid_o <= 0;
        end else begin
            valid_o <= 0;
            case (state)
                S_IDLE: begin
                    if (rx_i == 0) begin   // detecto start bit
                        cnt   <= 1;
                        state <= S_START;
                    end
                end
                S_START: begin
                    if (cnt == HALF_BIT) begin  // centro del start bit
                        cnt     <= 1;
                        bit_idx <= 0;
                        state   <= S_DATA;
                    end else
                        cnt <= cnt + 1;
                end
                S_DATA: begin
                    if (cnt == CLKS_PER_BIT) begin
                        shift[bit_idx] <= rx_i;
                        cnt     <= 1;
                        if (bit_idx == 7)
                            state <= S_STOP;
                        else
                            bit_idx <= bit_idx + 1;
                    end else
                        cnt <= cnt + 1;
                end
                S_STOP: begin
                    if (cnt == CLKS_PER_BIT) begin
                        data_o  <= shift;
                        valid_o <= 1;
                        state   <= S_IDLE;
                        cnt     <= 0;
                    end else
                        cnt <= cnt + 1;
                end
            endcase
        end
    end
endmodule
