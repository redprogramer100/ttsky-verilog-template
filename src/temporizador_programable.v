/*
 * temporizador_programable.v
 *
 * OPTIMIZACIÓN ASIC: Diseño basado en contadores en cascada.
 * Se eliminaron los multiplicadores gigantes (3600, 60) para reducir 
 * masivamente el área lógica en el tile de Tiny Tapeout.
 */
/*
 * temporizador_programable.v
 * Generador de ventana de tiempo y reloj de 1Hz base.
 */
`default_nettype none
module temporizador_programable #(
    parameter CLK_FREQ = 50000000
)(
    input  wire clk_i, reset_i, start_i, horaLista_i,
    input  wire [7:0] horas_i, minutos_i, segundos_i,
    output reg  salida_o, activo_o, tick_1hz_o
);
    reg start_prev;
    wire start_rise = start_i & ~start_prev;

    reg [25:0] div_cnt;
    reg [7:0] h; reg [5:0] m; reg [5:0] s; // Solo usamos estos registros para contar

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            {h, m, s} <= 20'd0; {activo_o, salida_o, tick_1hz_o, start_prev} <= 4'b0;
            div_cnt <= 26'd0;
        end else begin
            start_prev <= start_i;
            
            // Generador de 1Hz
            `ifdef COCOTB
                if (div_cnt == 26'd50) begin div_cnt <= 26'd0; tick_1hz_o <= 1'b1; end
            `else
                if (div_cnt == (CLK_FREQ[25:0] - 26'd1)) begin div_cnt <= 26'd0; tick_1hz_o <= 1'b1; end
            `endif
            else begin div_cnt <= div_cnt + 26'd1; tick_1hz_o <= 1'b0; end

            // Lógica de carga y descuento
            if (start_rise) begin
                {h, m, s} <= {horas_i, minutos_i[5:0], segundos_i[5:0]};
                salida_o <= 1'b0;
                activo_o <= (horas_i | minutos_i | segundos_i) ? 1'b1 : 1'b0;
                if (!(horas_i | minutos_i | segundos_i)) salida_o <= 1'b1;
            end else if (activo_o && tick_1hz_o) begin
                if (s > 0) s <= s - 6'd1;
                else if (m > 0) begin s <= 6'd59; m <= m - 6'd1; end
                else if (h > 0) begin s <= 6'd59; m <= 6'd59; h <= h - 8'd1; end
                else begin activo_o <= 1'b0; salida_o <= 1'b1; end
            end
        end
    end
endmodule