/*
 * frecuencimetro.v
 *
 * Technique: Reciprocal counting -> Frequency = (Pulses * CLK_FREQ) / Time_Cycles
 *
 * This module calculates the frequency of an input signal with high precision
 * by counting both signal pulses and system clock cycles over a gate period.
 * It uses a 2-stage pipeline to handle mathematical operations without 
 * affecting the timing of the ASIC.
 */
/*
 * frecuencimetro.v
 * Optimizado: Recibe el tick de 1Hz externamente para ahorrar área.
 */
`default_nettype none
module frecuencimetro (
    input  wire        clk_i, reset_i, enable_i,
    input  wire        P_clean_i, // Recibe señal ya sincronizada
    input  wire        tick_1hz_i,
    output reg  [15:0] frecuencia_o, output reg dato_listo_o
);
    reg [15:0] pulse_cnt;
    reg        sync_old; // Solo 1 registro para detectar flanco

    always @(posedge clk_i) sync_old <= P_clean_i;
    wire flanco_subida = P_clean_i & ~sync_old;

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin {pulse_cnt, frecuencia_o, dato_listo_o} <= 33'd0; end
        else if (!enable_i) begin pulse_cnt <= 16'd0; dato_listo_o <= 1'b0; end
        else begin
            if (tick_1hz_i) begin frecuencia_o <= pulse_cnt; dato_listo_o <= 1'b1; pulse_cnt <= 16'd0; end
            else begin if (flanco_subida) pulse_cnt <= pulse_cnt + 16'd1; dato_listo_o <= 1'b0; end
        end
    end
endmodule