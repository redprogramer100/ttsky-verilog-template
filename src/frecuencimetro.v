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
    input  wire        clk_i,
    input  wire        reset_i,
    input  wire        enable_i,
    input  wire        pulso_i,
    input  wire        tick_1hz_i,    // <-- ENTRADA DEL PULSO MAESTRO
    output reg  [15:0] frecuencia_o,
    output reg         dato_listo_o
);

    reg [15:0] pulse_cnt;
    reg [1:0]  sync;

    always @(posedge clk_i) begin
        sync <= {sync[0], pulso_i};
    end

    wire flanco_subida = sync[0] & ~sync[1];

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            pulse_cnt    <= 16'd0;
            frecuencia_o <= 16'd0;
            dato_listo_o <= 1'b0;
        end else if (!enable_i) begin
            pulse_cnt    <= 16'd0;
            dato_listo_o <= 1'b0;
        end else begin
            // Cuando el temporizador avisa que pasó 1 segundo exacto
            if (tick_1hz_i) begin
                frecuencia_o <= pulse_cnt; 
                dato_listo_o <= 1'b1;
                pulse_cnt    <= 16'd0;
            end else begin
                // Mientras tanto, seguimos sumando pulsos
                if (flanco_subida) begin
                    pulse_cnt <= pulse_cnt + 16'd1;
                end
                dato_listo_o <= 1'b0;
            end
        end
    end
endmodule