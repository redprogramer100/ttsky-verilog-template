`timescale 1ns/1ps

module tb ();

    // Entradas / salidas del DUT
    reg  clk;
    reg  rst_n;
    reg  [7:0] ui_in;
    reg  [7:0] uio_in;
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    // Instancia del DUT
    tt_um_Richard_Tarqui_contador_uart_simple dut (
        .ui_in   (ui_in),
        .uo_out  (uo_out),
        .uio_in  (uio_in),
        .uio_out (uio_out),
        .uio_oe  (uio_oe),
        .clk     (clk),
        .rst_n   (rst_n)
    );

    // Clock 50 MHz → periodo 20 ns
    initial clk = 0;
    always #10 clk = ~clk;

    // Volcado de formas de onda
    initial begin
        $dumpfile("tb.fst");
        $dumpvars(0, tb);
    end

endmodule
