/*
 * frecuencimetro.v
 *
 * Optmizado para síntesis (GDS compatible).
 * Elimina el operador de división '/' que bloquea el flujo de OpenLane.
 * Usa una ventana de tiempo de 1 segundo (GATE_SEC).
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

    // ---------------------------------------------------------
    // Sincronización y detección de flancos
    // ---------------------------------------------------------
    reg [2:0] sync_reg;
    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) sync_reg <= 3'b000;
        else         sync_reg <= {sync_reg[1:0], pulso_i};
    end

    wire flanco_subida = (sync_reg[1] && !sync_reg[2]);

    // ---------------------------------------------------------
    // Contadores
    // ---------------------------------------------------------
    reg [31:0] cnt_ciclos;
    reg [31:0] cnt_pulsos;
    
    // El límite de ciclos para 1 segundo (50,000,000 ciclos)
    localparam [31:0] TICKS_1SEC = CLK_FREQ * GATE_SEC;

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            cnt_ciclos   <= 32'd0;
            cnt_pulsos   <= 32'd0;
            frecuencia_o <= 32'd0;
            dato_listo_o <= 1'b0;
        end else if (!enable_i) begin
            cnt_ciclos   <= 32'd0;
            cnt_pulsos   <= 32'd0;
            dato_listo_o <= 1'b0;
        end else begin
            // Por defecto, bajar bandera de listo
            dato_listo_o <= 1'b0;

            // Contar pulsos de la señal de entrada
            if (flanco_subida) begin
                cnt_pulsos <= cnt_pulsos + 1;
            end

            // Ventana de tiempo (1 segundo)
            if (cnt_ciclos >= TICKS_1SEC - 1) begin
                // En una ventana de exactamente 1 segundo:
                // Frecuencia (Hz) = Cantidad de pulsos detectados
                frecuencia_o <= cnt_pulsos + (flanco_subida ? 1 : 0);
                
                // Reiniciar contadores
                cnt_ciclos   <= 32'd0;
                cnt_pulsos   <= 32'd0;
                dato_listo_o <= 1'b1;
            end else begin
                cnt_ciclos <= cnt_ciclos + 1;
            end
        end
    end

endmodule