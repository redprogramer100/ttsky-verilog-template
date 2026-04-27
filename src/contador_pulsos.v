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
    input  wire        clk_i,
    input  wire        reset_i,
    input  wire        enable_i,
    input  wire        P1_i,
    output reg  [15:0] contador_o, // <--- REDUCIDO A 16 BITS
    output wire        sin_pulso_o
);

    reg [1:0] sync;
    
    // Sincronizador
    always @(posedge clk_i) begin
        sync <= {sync[0], P1_i};
    end
    
    // Detector de flanco de bajada (Falling Edge)
    wire flanco_bajada = ~sync[0] & sync[1];

    assign sin_pulso_o = (contador_o == 16'd0);

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            contador_o <= 16'd0;
        end else if (!enable_i) begin
            contador_o <= 16'd0; 
        end else if (flanco_bajada) begin
            contador_o <= contador_o + 16'd1;
        end
    end

endmodule