/*
 * contador_pulsos.v
 *
 * Falling edge counter for a single channel.
 * This module tracks the total number of pulses detected during the 
 * measurement window (enable_sys).
 *
 * Technique: 2-stage synchronization + Falling edge detection logic.
 */

module contador_pulsos (
    input  wire        clk_i,       // System clock (Default 50 MHz)
    input  wire        reset_i,     // Active-high reset: clears counter and flags
    input  wire        enable_i,    // 1 = Counting enabled | 0 = Paused (Value preserved)
    input  wire        P1_i,        // Target input signal to be counted
    output reg  [31:0] contador_o,  // Accumulated 32-bit pulse count
    output reg         sin_pulso_o  // 1 = No falling edge | 0 = Edge detected in current cycle
);

    // ---------------------------------------------------------
    //  Input Synchronization (Anti-metastability)
    //  Uses a 2-stage register to synchronize the asynchronous 
    //  input signal (P1_i) with the system clock.
    // ---------------------------------------------------------
    reg [1:0] sync1;

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i)
            sync1 <= 2'b00;
        else
            sync1 <= {sync1[0], P1_i};
    end

    // Internal synchronized signal
    wire P1_sync = sync1[1];
    reg  P1_prev;

    // ---------------------------------------------------------
    //  Falling Edge Detection Logic
    //  An edge is detected when the current sample is LOW (0) 
    //  AND the previous sample was HIGH (1).
    // ---------------------------------------------------------
    wire flanco = ~P1_sync & P1_prev;

    // ---------------------------------------------------------
    //  Main Logic: Counting and Pulse Flagging
    // ---------------------------------------------------------
    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            P1_prev     <= 1'b0;
            contador_o  <= 32'd0;
            sin_pulso_o <= 1'b1;
        end else begin
            // Update previous state for edge detection
            P1_prev <= P1_sync;
            
            if (enable_i) begin
                if (flanco) begin
                    // Increment count and clear "no-pulse" flag
                    contador_o  <= contador_o + 1;
                    sin_pulso_o <= 1'b0;
                end else begin
                    // Stay in "no-pulse" state if no falling edge occurs
                    sin_pulso_o <= 1'b1;
                end
            end
            // Note: If enable_i is LOW, contador_o holds its last value
        end
    end

endmodule