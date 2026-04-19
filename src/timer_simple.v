module timer_simple #(
    parameter CLK_FREQ = 50_000_000
)(
    input  wire clk_i,
    input  wire reset_i,
    input  wire start_i,
    input  wire [23:0] tiempo_i,

    output reg activo_o
);

    localparam DIV = CLK_FREQ - 1;

    reg [31:0] div_cnt;
    reg tick;

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            div_cnt <= 0;
            tick <= 0;
        end else begin
            if (div_cnt == DIV) begin
                div_cnt <= 0;
                tick <= 1;
            end else begin
                div_cnt <= div_cnt + 1;
                tick <= 0;
            end
        end
    end

    reg [23:0] counter;

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            activo_o <= 0;
            counter <= 0;
        end else begin

            if (start_i) begin
                counter <= tiempo_i;
                activo_o <= (tiempo_i != 0);
            end

            else if (activo_o && tick) begin
                if (counter > 1)
                    counter <= counter - 1;
                else begin
                    counter <= 0;
                    activo_o <= 0;
                end
            end
        end
    end
endmodule