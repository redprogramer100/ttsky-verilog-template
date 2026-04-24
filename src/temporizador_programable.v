
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
    reg start_prev;
    wire start_rise = start_i & ~start_prev;
    reg hora_prev;
    wire hora_rise = horaLista_i & ~hora_prev;
    reg hora_cargada;
    reg [31:0] div_cnt;
    reg tick_1hz;
    reg [31:0] contador;
    wire [31:0] tiempo_total = (horas_i * 32'd3600) + (minutos_i * 32'd60) + {24'd0, segundos_i};

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            start_prev <= 1'b0; hora_prev <= 1'b0; hora_cargada <= 1'b0;
            div_cnt <= 32'd0; tick_1hz <= 1'b0; contador <= 32'd0;
            salida_o <= 1'b0; activo_o <= 1'b0;
        end else begin
            start_prev <= start_i;
            hora_prev <= horaLista_i;
            if (hora_rise) hora_cargada <= 1'b1;
            else if (start_rise) hora_cargada <= 1'b0;

            if (div_cnt == (CLK_FREQ - 1)) begin div_cnt <= 32'd0; tick_1hz <= 1'b1; end
            else begin div_cnt <= div_cnt + 32'd1; tick_1hz <= 1'b0; end

            if (start_rise && hora_cargada) begin
                if (tiempo_total == 32'd0) begin salida_o <= 1'b1; activo_o <= 1'b0; end
                else begin contador <= tiempo_total; activo_o <= 1'b1; salida_o <= 1'b0; end
            end else if (activo_o && tick_1hz) begin
                if (contador > 32'd1) contador <= contador - 32'd1;
                else begin activo_o <= 1'b0; contador <= 32'd0; end
            end
        end
    end
endmodule