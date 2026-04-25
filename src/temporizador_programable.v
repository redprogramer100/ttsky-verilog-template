/*
 * temporizador_programable.v
 * Optimizado para ASIC 1x1: Usa cascada de 8 bits en vez de multiplicadores de 32 bits.
 */
module temporizador_programable #(
    parameter CLK_FREQ = 50000000
)(
    input  wire        clk_i,
    input  wire        reset_i,
    input  wire        start_i,
    input  wire        horaLista_i,
    input  wire [7:0]  horas_i,
    input  wire [7:0]  minutos_i,
    input  wire [7:0]  segundos_i,
    output reg         salida_o,
    output reg         activo_o
);

    reg start_prev, hora_prev, hora_cargada;
    wire start_rise = start_i & ~start_prev;
    wire hora_rise  = horaLista_i & ~hora_prev;

    reg [31:0] div_cnt;
    wire tick_1hz = (div_cnt == (CLK_FREQ - 1));

    reg [7:0] reg_h, reg_m, reg_s;

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            start_prev <= 0; hora_prev <= 0; hora_cargada <= 0;
            div_cnt <= 0; salida_o <= 0; activo_o <= 0;
            reg_h <= 0; reg_m <= 0; reg_s <= 0;
        end else begin
            start_prev <= start_i;
            hora_prev  <= horaLista_i;
            
            if (hora_rise) hora_cargada <= 1'b1;
            else if (start_rise) hora_cargada <= 1'b0;

            if (tick_1hz) div_cnt <= 32'd0;
            else          div_cnt <= div_cnt + 32'd1;

            if (start_rise && hora_cargada) begin
                if (horas_i == 0 && minutos_i == 0 && segundos_i == 0) begin
                    salida_o <= 1'b1; activo_o <= 1'b0; 
                end else begin
                    reg_h <= horas_i; reg_m <= minutos_i; reg_s <= segundos_i;
                    activo_o <= 1'b1; salida_o <= 1'b0; div_cnt <= 32'd0;
                end
            end else if (activo_o && tick_1hz) begin
                if (reg_s > 0) begin
                    reg_s <= reg_s - 8'd1;
                end else if (reg_m > 0) begin
                    reg_m <= reg_m - 8'd1; reg_s <= 8'd59;
                end else if (reg_h > 0) begin
                    reg_h <= reg_h - 8'd1; reg_m <= 8'd59; reg_s <= 8'd59;
                end else begin
                    activo_o <= 1'b0; salida_o <= 1'b1; 
                end
            end
        end
    end
endmodule