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
    parameter CLK_FREQ = 50_000_000, // System clock in Hz
    parameter GATE_SEC = 3           // Measurement window duration in seconds
)(
    input  wire        clk_i,        // Main system clock
    input  wire        reset_i,      // Active-high reset
    input  wire        enable_i,     // Enable measurement (1 = active)
    input  wire        pulso_i,      // Input signal to be measured
    output reg  [31:0] frecuencia_o, // Measured frequency in Hz
    output reg         dato_listo_o  // 1 = Result valid | 0 = Calculating
);

    // Total clock cycles for the gate window
    localparam [31:0] GATE_CYCLES = CLK_FREQ * GATE_SEC;

    // ---------------------------------------------------------
    // Input Synchronization
    // 2-stage synchronizer to prevent metastability from the input signal
    // ---------------------------------------------------------
    reg [1:0] sync;

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i)
            sync <= 2'b00;
        else
            sync <= {sync[0], pulso_i};
    end

    wire pulso_sync = sync[1];
    reg  pulso_prev;
    
    // Rising edge detection
    wire flanco = pulso_sync & ~pulso_prev;

    // ---------------------------------------------------------
    // Counters and Registers
    // ---------------------------------------------------------
    reg [31:0] cnt_ciclos; // Counter for system clock cycles
    reg [31:0] cnt_pulsos; // Counter for input signal pulses

    reg [31:0] cap_ciclos; // Captured cycles at the end of the window
    reg [31:0] cap_pulsos; // Captured pulses at the end of the window

    // ---------------------------------------------------------
    // Pipeline Registers
    // Used to split the multiplication and division into different clock cycles
    // ---------------------------------------------------------
    reg [63:0] prod;
    reg calcular_d1; // Stage 1: Multiplication
    reg calcular_d2; // Stage 2: Division

    // ---------------------------------------------------------
    // Main Measurement Logic
    // ---------------------------------------------------------
    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            cnt_ciclos   <= 0;
            cnt_pulsos   <= 0;
            cap_ciclos   <= 1;
            cap_pulsos   <= 0;
            pulso_prev   <= 0;

            calcular_d1  <= 0;
            calcular_d2  <= 0;

            prod         <= 0;
            frecuencia_o <= 0;
            dato_listo_o <= 0;

        end else if (!enable_i) begin
            // Reset counters and pipeline when disabled
            cnt_ciclos   <= 0;
            cnt_pulsos   <= 0;
            cap_ciclos   <= 1;
            cap_pulsos   <= 0;
            pulso_prev   <= 0;

            calcular_d1  <= 0;
            calcular_d2  <= 0;

            prod         <= 0;
            frecuencia_o <= 0;
            dato_listo_o <= 0;

        end else begin

            // Edge detection update
            pulso_prev <= pulso_sync;

            if (flanco)
                cnt_pulsos <= cnt_pulsos + 1;

            // -----------------------------------------------------
            // Measurement Window (Gate)
            // -----------------------------------------------------
            if (cnt_ciclos >= GATE_CYCLES - 1) begin
                // Capture current counts
                cap_ciclos <= cnt_ciclos + 1;
                cap_pulsos <= cnt_pulsos + (flanco ? 1 : 0);

                // Reset internal counters for next window
                cnt_ciclos <= 0;
                cnt_pulsos <= 0;

                // Trigger pipeline Stage 1
                calcular_d1 <= 1'b1;
                dato_listo_o <= 0;

            end else begin
                cnt_ciclos <= cnt_ciclos + 1;
                calcular_d1 <= 1'b0;
            end

            // -----------------------------------------------------
            // Mathematical Pipeline (2 Stages)
            // Splitting math operations improves timing slack in ASIC
            // -----------------------------------------------------
            calcular_d2 <= calcular_d1;

            // Stage 1: Multiplication (Pulses * Clock Frequency)
            if (calcular_d1)
                prod <= cap_pulsos * CLK_FREQ;

            // Stage 2: Division (Product / Captured Cycles)
            if (calcular_d2) begin
                if (cap_ciclos > 0)
                    frecuencia_o <= prod / cap_ciclos;
                else
                    frecuencia_o <= 0;

                // Signal that result is ready for telemetry
                dato_listo_o <= 1'b1;
            end

        end
    end

endmodule