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
 module frecuencimetro #(
    parameter CLK_FREQ = 50_000_000,
    parameter GATE_SEC = 1           // <--- Agregamos esto
)(
    input  wire        clk_i,
    input  wire        reset_i,
    input  wire        enable_i,
    input  wire        pulso_i,
    output reg  [31:0] frecuencia_o, 
    output reg         dato_listo_o
);

    reg [31:0] clk_cnt;
    reg [31:0] pulse_cnt;
    reg [1:0]  sync;

    always @(posedge clk_i) sync <= {sync[0], pulso_i};
    wire flanco_subida = sync[0] & ~sync[1];

    // Ahora el tiempo de la ventana depende del parámetro
    localparam [31:0] GATE_CYCLES = CLK_FREQ * GATE_SEC;

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i || !enable_i) begin
            clk_cnt      <= 0;
            pulse_cnt    <= 0;
            frecuencia_o <= 0;
            dato_listo_o <= 0;
        end else begin
            if (flanco_subida) pulse_cnt <= pulse_cnt + 1;

            if (clk_cnt >= (GATE_CYCLES - 1)) begin
                frecuencia_o <= pulse_cnt; 
                dato_listo_o <= 1;
                clk_cnt      <= 0;
                pulse_cnt    <= 0;
            end else begin
                clk_cnt      <= clk_cnt + 1;
                dato_listo_o <= 0;
            end
        end
    end
endmodule