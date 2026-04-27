`default_nettype none
`timescale 1ns/1ps

module tb (
    input clk,
    input rst_n,
    input ena,
    input [7:0] ui_in,
    input [7:0] uio_in,
    output [7:0] uo_out,
    output [7:0] uio_out,
    output [7:0] uio_oe
);

    tt_um_Richard_Tarqui_contador_uart_simple user_project (
        .ui_in   (ui_in),
        .uo_out  (uo_out),
        .uio_in  (uio_in),
        .uio_out (uio_out),
        .uio_oe  (uio_oe),
        .ena     (ena),
        .clk     (clk),
        .rst_n   (rst_n)
    );

    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
        #1;
    end

endmodule