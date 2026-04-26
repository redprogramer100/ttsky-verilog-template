/*
 * uart_tx.v
 *
 * Standard UART Transmitter (8 data bits, 1 stop bit, no parity).
 *
 * This module converts an 8-bit parallel byte into a serial stream. 
 * It manages the insertion of the START bit (LOW) and the STOP bit (HIGH) 
 * while maintaining the correct baudrate timing based on the system clock.
 */

module uart_tx #(
    parameter CLK_FREQ = 50_000_000, // System clock frequency
    parameter BAUDRATE = 115200      // Targeted baudrate
)(
    input  wire       clk_i,      // System clock
    input  wire       reset_i,    // Active-high master reset
    
    // Interface compatible with uart_trama_sender
    input  wire [7:0] data_i,     // Parallel byte to be transmitted
    input  wire       valid_i,    // Pulse to trigger the start of transmission
    output reg        ready_o,    // 1 = Idle/Ready to accept a new byte
    output reg        tx_done_o,  // Single-cycle pulse indicating End of Transmission
    output reg        tx_o        // Physical UART TX serial output
);

    // Calculate clock cycles required for each bit period
    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUDRATE;

    // FSM State Definitions
    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    reg [1:0]  state;
    reg [15:0] clk_cnt;
    reg [2:0]  bit_index;
    reg [7:0]  data_reg;

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            state      <= IDLE;
            tx_o       <= 1'b1;  // UART TX idle line state is HIGH
            ready_o    <= 1'b1;  // Ready by default
            tx_done_o  <= 1'b0;
            clk_cnt    <= 0;
            bit_index  <= 0;
            data_reg   <= 0;
        end else begin
            // Default pulse duration for tx_done_o is one clock cycle
            tx_done_o <= 1'b0;

            case (state)
                
                // Wait for the valid_i pulse to begin transmission
                IDLE: begin
                    tx_o    <= 1'b1;
                    ready_o <= 1'b1;
                    
                    if (valid_i) begin
                        data_reg <= data_i; // Buffer the input data
                        ready_o  <= 1'b0;   // Signal module is now busy
                        clk_cnt  <= 0;
                        state    <= START;
                    end
                end

                // Transmission of the START bit (Logic LOW)
                START: begin
                    tx_o <= 1'b0;
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 1;
                    end else begin
                        clk_cnt   <= 0;
                        bit_index <= 0;
                        state     <= DATA;
                    end
                end

                // Serial transmission of the 8 data bits (LSB first)
                DATA: begin
                    tx_o <= data_reg[bit_index]; 
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 1;
                    end else begin
                        clk_cnt <= 0;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            bit_index <= 0;
                            state     <= STOP;
                        end
                    end
                end

                // Transmission of the STOP bit (Logic HIGH)
                STOP: begin
                    tx_o <= 1'b1;
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 1;
                    end else begin
                        clk_cnt   <= 0;
                        tx_done_o <= 1'b1; // Signal that the transmission is complete
                        state     <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule