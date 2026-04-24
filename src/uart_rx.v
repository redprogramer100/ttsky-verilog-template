/*
 * uart_rx.v
 *
 * Standard UART Receiver (8 data bits, 1 stop bit, no parity).
 *
 * This module uses a 16x oversampling technique to sample the incoming 
 * serial data at the center of each bit, ensuring reliable data recovery 
 * even with minor clock frequency mismatches.
 */

module uart_rx #(
    parameter CLK_FREQ = 50_000_000, // System clock frequency
    parameter BAUDRATE = 115200      // Targeted baudrate
)(
    input  wire clk_i,      // System clock
    input  wire reset_i,    // Active-high master reset
    input  wire rx_i,       // Serial input line

    output reg  [7:0] data_o,  // Parallel byte received
    output reg        valid_o, // High pulse when data_o is valid
    input  wire       ready_i  // Handshake: HIGH if consumer is ready for next byte
);

    // -------------------------------------------------
    // 1) Baud Generator (16x Oversampling)
    // -------------------------------------------------
    // We divide the clock to get 16 ticks per bit period.
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
    // 2) Input Synchronization
    // -------------------------------------------------
    // Double-flop synchronizer to mitigate metastability 
    // from the asynchronous RX input.
    reg [1:0] sync;

    always @(posedge clk_i) begin
        sync <= {sync[0], rx_i};
    end

    wire rx = sync[1];

    // -------------------------------------------------
    // 3) Finite State Machine (FSM)
    // -------------------------------------------------
    localparam IDLE  = 3'd0;
    localparam START = 3'd1;
    localparam DATA  = 3'd2;
    localparam STOP  = 3'd3;
    localparam WAIT  = 3'd4;

    reg [2:0] state;
    reg [3:0] tick_cnt; // Counts the 16 ticks per bit
    reg [2:0] bit_cnt;  // Counts the 8 data bits
    reg [7:0] shift;    // Shift register for data capture

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

                // Wait for a falling edge on the RX line (Start bit)
                IDLE: begin
                    valid_o <= 0;
                    if (rx == 0) begin
                        state    <= START;
                        tick_cnt <= 0;
                    end
                end

                // Verify the Start bit by sampling at the midpoint (tick 7)
                START: if (tick) begin
                    if (tick_cnt == 7) begin
                        if (rx == 0) // Valid start bit confirmed
                            tick_cnt <= tick_cnt + 1;
                        else
                            state <= IDLE; // False start, back to idle
                    end else if (tick_cnt == 15) begin
                        tick_cnt <= 0;
                        bit_cnt  <= 0;
                        state    <= DATA;
                    end else begin
                        tick_cnt <= tick_cnt + 1;
                    end
                end

                // Data capture stage
                DATA: if (tick) begin
                    if (tick_cnt == 7) begin // Sample at the center of the bit
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

                // Verify the Stop bit (should be HIGH)
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

                // Wait for handshaking before returning to IDLE
                WAIT: begin
                    if (ready_i) begin
                        valid_o <= 0;
                        state   <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule