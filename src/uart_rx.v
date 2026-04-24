module uart_rx #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUDRATE = 115200
)(
    input  wire clk_i,
    input  wire reset_i,
    input  wire rx_i,

    output reg  [7:0] data_o,
    output reg        valid_o,
    input  wire       ready_i
);

    // -------------------------------------------------
    // Baud generator (x16 oversampling)
    // -------------------------------------------------
    localparam integer CLKS_PER_TICK = CLK_FREQ / (BAUDRATE * 16);

    reg [15:0] clk_cnt;
    reg        tick;

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            clk_cnt <= 0;
            tick    <= 0;
        end else begin
            if (clk_cnt == CLKS_PER_TICK - 1) begin
                clk_cnt <= 0;
                tick    <= 1;
            end else begin
                clk_cnt <= clk_cnt + 1;
                tick    <= 0;
            end
        end
    end

    // -------------------------------------------------
    // Sincronización entrada
    // -------------------------------------------------
    reg [1:0] sync;

    always @(posedge clk_i) begin
        sync <= {sync[0], rx_i};
    end

    wire rx = sync[1];

    // -------------------------------------------------
    // FSM
    // -------------------------------------------------
    localparam IDLE  = 3'd0;
    localparam START = 3'd1;
    localparam DATA  = 3'd2;
    localparam STOP  = 3'd3;
    localparam WAIT  = 3'd4;

    reg [2:0] state;
    reg [3:0] tick_cnt;
    reg [2:0] bit_cnt;
    reg [7:0] shift;

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            state    <= IDLE;
            tick_cnt <= 0;
            bit_cnt  <= 0;
            shift    <= 0;
            data_o   <= 0;
            valid_o  <= 0;

        end else begin
            case (state)

                IDLE: begin
                    valid_o <= 0;
                    if (rx == 0) begin
                        state    <= START;
                        tick_cnt <= 0;
                    end
                end

                START: if (tick) begin
                    if (tick_cnt == 7) begin
                        if (rx == 0)
                            tick_cnt <= tick_cnt + 1;
                        else
                            state <= IDLE;
                    end else if (tick_cnt == 15) begin
                        tick_cnt <= 0;
                        bit_cnt  <= 0;
                        state    <= DATA;
                    end else begin
                        tick_cnt <= tick_cnt + 1;
                    end
                end

                DATA: if (tick) begin
                    if (tick_cnt == 7) begin
                        shift[bit_cnt] <= rx;
                        tick_cnt <= tick_cnt + 1;
                    end else if (tick_cnt == 15) begin
                        tick_cnt <= 0;
                        if (bit_cnt == 7)
                            state <= STOP;
                        else
                            bit_cnt <= bit_cnt + 1;
                    end else begin
                        tick_cnt <= tick_cnt + 1;
                    end
                end

                STOP: if (tick) begin
                    if (tick_cnt == 15) begin
                        data_o  <= shift;
                        valid_o <= 1;
                        state   <= WAIT;
                        tick_cnt <= 0;
                    end else begin
                        tick_cnt <= tick_cnt + 1;
                    end
                end

                WAIT: begin
                    if (ready_i) begin
                        valid_o <= 0;
                        state   <= IDLE;
                    end
                end

            endcase
        end
    end

endmodule
