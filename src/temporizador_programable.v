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
module temporizador_programable #(parameter CLK_FREQ = 50000000)(
    input  wire clk_i, reset_i, start_i,
    input  wire load_h, load_m, load_s,
    input  wire [7:0] data_i,
    output reg  salida_o, activo_o, tick_1hz_o
);
    reg [25:0] div_cnt;
    reg [7:0] h; reg [5:0] m; reg [5:0] s;

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            {h, m, s} <= 20'd0; {activo_o, salida_o, tick_1hz_o} <= 3'b0; div_cnt <= 0;
        end else begin
            if (load_h) h <= data_i;
            if (load_m) m <= data_i[5:0];
            if (load_s) s <= data_i[5:0];

            if (start_i) begin
                salida_o <= 0;
                activo_o <= (h|m|s) ? 1 : 0;
                if (!(h|m|s)) salida_o <= 1;
            end else if (activo_o) begin
                if (div_cnt == (CLK_FREQ[25:0]-1)) begin
                    div_cnt <= 0; tick_1hz_o <= 1;
                    if (s > 0) s <= s - 1;
                    else if (m > 0) begin s <= 59; m <= m - 1; end
                    else if (h > 0) begin s <= 59; m <= 59; h <= h - 1; end
                    else begin activo_o <= 0; salida_o <= 1; end
                end else begin div_cnt <= div_cnt + 1; tick_1hz_o <= 0; end
            end else begin div_cnt <= 0; tick_1hz_o <= 0; end
        end
    end
endmodule