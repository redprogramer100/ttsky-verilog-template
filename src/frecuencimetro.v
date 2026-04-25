module frecuencimetro #(
    parameter CLK_FREQ = 50_000_000,
    parameter GATE_SEC = 1 
)(
    input  wire        clk_i, reset_i, enable_i, pulso_i,
    output reg  [31:0] frecuencia_o,
    output reg         dato_listo_o
);

    reg [2:0] sync_reg;
    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) sync_reg <= 3'b000;
        else         sync_reg <= {sync_reg[1:0], pulso_i};
    end
    wire flanco_subida = (sync_reg[1] && !sync_reg[2]);

    reg [25:0] cnt_ciclos; // DIETA: 26 bits (para llegar a 50M)
    reg [31:0] cnt_pulsos;
    localparam [25:0] TICKS_1SEC = CLK_FREQ * GATE_SEC;

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            cnt_ciclos <= 0; cnt_pulsos <= 0; frecuencia_o <= 0; dato_listo_o <= 0;
        end else if (!enable_i) begin
            cnt_ciclos <= 0; cnt_pulsos <= 0; dato_listo_o <= 0;
        end else begin
            dato_listo_o <= 0;
            if (flanco_subida) cnt_pulsos <= cnt_pulsos + 1;

            if (cnt_ciclos >= TICKS_1SEC - 1) begin
                // DIETA: Eliminamos el + (flanco_subida ? 1 : 0) para ahorrar un sumador de 32 bits
                frecuencia_o <= cnt_pulsos; 
                cnt_ciclos   <= 0;
                cnt_pulsos   <= 0;
                dato_listo_o <= 1'b1;
            end else begin
                cnt_ciclos <= cnt_ciclos + 1;
            end
        end
    end
endmodule