`timescale 1us/1ns

module tb ();

    reg        clk;
    reg        rst_n;
    reg        ena;
    reg  [7:0] ui_in;
    reg  [7:0] uio_in;
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    tt_um_Richard_Tarqui_contador_uart_simple dut (
        .ui_in   (ui_in),
        .uo_out  (uo_out),
        .uio_in  (uio_in),
        .uio_out (uio_out),
        .uio_oe  (uio_oe),
        .ena     (ena),
        .clk     (clk),
        .rst_n   (rst_n)
    );

    initial clk = 0;
    always #5 clk = ~clk;  // 10 us periodo = 100 KHz

    initial begin
        $dumpfile("tb.fst");
        $dumpvars(0, tb);
        #1;
    end

endmodule
