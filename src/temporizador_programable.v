/*
 * temporizador_programable.v
 *
 * Optmizado para 1x1 Tile. 
 * Elimina los multiplicadores de 32 bits y usa contadores en cascada de 8 bits
 * para reducir drásticamente el área y la congestión de ruteo (routing congestion).
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

    // Detección de flancos
    reg start_prev;
    wire start_rise = start_i & ~start_prev;
    
    reg hora_prev;
    wire hora_rise = horaLista_i & ~hora_prev;
    reg hora_cargada;

    // Generador de 1Hz (Divisor de reloj)
    reg [31:0] div_cnt;
    wire tick_1hz = (div_cnt == (CLK_FREQ - 1));

    // Registros en cascada (Reemplazan al multiplicador gigante)
    reg [7:0] reg_h;
    reg [7:0] reg_m;
    reg [7:0] reg_s;

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            start_prev   <= 1'b0; 
            hora_prev    <= 1'b0; 
            hora_cargada <= 1'b0;
            div_cnt      <= 32'd0; 
            salida_o     <= 1'b0; 
            activo_o     <= 1'b0;
            reg_h        <= 8'd0;
            reg_m        <= 8'd0;
            reg_s        <= 8'd0;
        end else begin
            // Actualización de estado previo para flancos
            start_prev <= start_i;
            hora_prev  <= horaLista_i;
            
            if (hora_rise) hora_cargada <= 1'b1;
            else if (start_rise) hora_cargada <= 1'b0;

            // Divisor para el tick de 1 segundo
            if (tick_1hz) div_cnt <= 32'd0;
            else          div_cnt <= div_cnt + 32'd1;

            // Máquina de estados principal
            if (start_rise && hora_cargada) begin
                if (horas_i == 0 && minutos_i == 0 && segundos_i == 0) begin
                    salida_o <= 1'b1; 
                    activo_o <= 1'b0; 
                end else begin
                    // Cargar valores directamente a los registros de 8 bits
                    reg_h    <= horas_i;
                    reg_m    <= minutos_i;
                    reg_s    <= segundos_i;
                    activo_o <= 1'b1; 
                    salida_o <= 1'b0;
                    div_cnt  <= 32'd0; // Sincronizar el inicio del segundo
                end
            end else if (activo_o && tick_1hz) begin
                // Lógica en cascada: mucho más barata en hardware
                if (reg_s > 0) begin
                    reg_s <= reg_s - 8'd1;
                end else if (reg_m > 0) begin
                    reg_m <= reg_m - 8'd1;
                    reg_s <= 8'd59;
                end else if (reg_h > 0) begin
                    reg_h <= reg_h - 8'd1;
                    reg_m <= 8'd59;
                    reg_s <= 8'd59;
                end else begin
                    // Fin de la cuenta
                    activo_o <= 1'b0; 
                    salida_o <= 1'b1; 
                end
            end
        end
    end

endmodule