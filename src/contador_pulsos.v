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
    input  wire        clk_i, reset_i, enable_i,
    input  wire        P_clean_i, // Recibe señal ya sincronizada
    output reg  [15:0] contador_o, output wire sin_pulso_o
);
    reg sync_old;
    always @(posedge clk_i) sync_old <= P_clean_i;
    wire flanco_bajada = ~P_clean_i & sync_old;

    assign sin_pulso_o = (contador_o == 16'd0);

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) contador_o <= 16'd0;
        else if (!enable_i) contador_o <= 16'd0; 
        else if (flanco_bajada) contador_o <= contador_o + 16'd1;
    end
endmodule