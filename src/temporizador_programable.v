/*
 * temporizador_programable.v
 *
 * OPTIMIZACIÓN ASIC: Diseño basado en contadores en cascada.
 * Se eliminaron los multiplicadores gigantes (3600, 60) para reducir 
 * masivamente el área lógica en el tile de Tiny Tapeout.
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
    wire hora_rise = horaLista_i & ~hora_prev;

    reg [31:0] div_cnt;
    reg tick_1hz;

    // Registros ajustados al tamaño necesario para ahorrar área
    reg [7:0] cnt_h; // 8 bits (0-255 horas)
    reg [5:0] cnt_m; // 6 bits (0-59 minutos)
    reg [5:0] cnt_s; // 6 bits (0-59 segundos)

    // Comparador Triple (Bajo consumo de área combinacional)
    wire meta_alcanzada = (cnt_h == horas_i) && 
                          ({2'b00, cnt_m} == minutos_i) && 
                          ({2'b00, cnt_s} == segundos_i);

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            start_prev   <= 1'b0; 
            hora_prev    <= 1'b0; 
            hora_cargada <= 1'b0;
            div_cnt      <= 32'd0; 
            tick_1hz     <= 1'b0;
            cnt_h        <= 8'd0; 
            cnt_m        <= 6'd0; 
            cnt_s        <= 6'd0;
            salida_o     <= 1'b0; 
            activo_o     <= 1'b0;
        end else begin
            start_prev <= start_i;
            hora_prev  <= horaLista_i;

            if (hora_rise) hora_cargada <= 1'b1;
            else if (start_rise) hora_cargada <= 1'b0;

            // Generador de prescaler (1Hz)
            if (div_cnt == (CLK_FREQ - 1)) begin 
                div_cnt <= 32'd0; 
                tick_1hz <= 1'b1; 
            end else begin 
                div_cnt <= div_cnt + 32'd1; 
                tick_1hz <= 1'b0; 
            end

            // Lógica de Control y Cascada de contadores
            if (start_rise && hora_cargada) begin
                // Iniciar medición: Reset de contadores
                cnt_h    <= 8'd0; 
                cnt_m    <= 6'd0; 
                cnt_s    <= 6'd0;
                salida_o <= 1'b0;
                activo_o <= 1'b1;
                
                // Caso especial: si la hora cargada es 00:00:00
                if (horas_i == 0 && minutos_i == 0 && segundos_i == 0) begin
                    salida_o <= 1'b1;
                    activo_o <= 1'b0;
                end
                
            end else if (activo_o) begin
                if (meta_alcanzada) begin
                    salida_o <= 1'b1; // ¡Tiempo cumplido!
                    activo_o <= 1'b0;
                end else if (tick_1hz) begin
                    // El "Dominó" de los contadores
                    if (cnt_s == 6'd59) begin
                        cnt_s <= 6'd0;
                        if (cnt_m == 6'd59) begin
                            cnt_m <= 6'd0;
                            cnt_h <= cnt_h + 8'd1;
                        end else begin
                            cnt_m <= cnt_m + 6'd1;
                        end
                    end else begin
                        cnt_s <= cnt_s + 6'd1;
                    end
                end
            end
        end
    end
endmodule