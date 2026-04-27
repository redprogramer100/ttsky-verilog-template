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
    parameter GATE_SEC = 1
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

    // Sincronizador de 2 etapas aislado
    always @(posedge clk_i) begin
        sync <= {sync[0], pulso_i};
    end

    // Detección de flanco de subida limpio
    wire flanco_subida = sync[0] & ~sync[1];

    localparam [31:0] GATE_CYCLES = CLK_FREQ * GATE_SEC;

    // LÓGICA PRINCIPAL: Separación estricta de Reset y Enable para Yosys
    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            // 1. Reset Asíncrono (Hardware puro)
            clk_cnt      <= 32'd0;
            pulse_cnt    <= 32'd0;
            frecuencia_o <= 32'd0;
            dato_listo_o <= 1'b0;
        end else if (!enable_i) begin
            // 2. Limpieza Síncrona (Cuando el sistema está apagado)
            clk_cnt      <= 32'd0;
            pulse_cnt    <= 32'd0;
            dato_listo_o <= 1'b0;
        end else begin
            // 3. Operación normal
            if (flanco_subida) begin
                pulse_cnt <= pulse_cnt + 32'd1;
            end

            if (clk_cnt >= (GATE_CYCLES - 1)) begin
                frecuencia_o <= pulse_cnt; 
                dato_listo_o <= 1'b1;
                clk_cnt      <= 32'd0;
                pulse_cnt    <= 32'd0;
            end else begin
                clk_cnt      <= clk_cnt + 32'd1;
                dato_listo_o <= 1'b0;
            end
        end
    end
endmodule