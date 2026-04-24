module tt_um_Richard_Tarqui_contador_uart_simple (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
    // Suprimir warnings de pines no usados
    wire _unused = &{ena, uio_in, ui_in[7:1]};

    wire rx  = ui_in[0];
    wire rst = ~rst_n;

    wire tx;
    wire activo;
    wire [7:0] rx_data;
    wire rx_valid;

    uart_rx #(.CLK_FREQ(50_000_000), .BAUDRATE(115_200)) u_rx (
        .clk_i(clk),
        .reset_i(rst),
        .rx_i(rx),
        .data_o(rx_data),
        .valid_o(rx_valid)
    );

    wire start, reset_cmd;
    wire [23:0] tiempo;

    cmd_decoder u_cmd (
        .clk_i(clk),
        .reset_i(rst),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .start_o(start),
        .reset_o(reset_cmd),
        .tiempo_o(tiempo)
    );

    timer_simple u_timer (
        .clk_i(clk),
        .reset_i(rst | reset_cmd),
        .start_i(start),
        .tiempo_i(tiempo),
        .activo_o(activo)
    );

    wire tx_ready;
    reg  tx_valid;
    reg  [7:0] tx_data;

    uart_tx #(.CLK_FREQ(50_000_000), .BAUDRATE(115_200)) u_tx (
        .clk_i(clk),
        .reset_i(rst),
        .data_i(tx_data),
        .valid_i(tx_valid),
        .ready_o(tx_ready),
        .tx_o(tx)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_valid <= 0;
            tx_data  <= 0;
        end else begin
            tx_valid <= 0;
            if (tx_ready) begin
                tx_data  <= {7'b0, activo};
                tx_valid <= 1;
            end
        end
    end

    assign uo_out[0]   = tx;
    assign uo_out[1]   = activo;
    assign uo_out[7:2] = 6'b0;
    assign uio_out     = 8'b0;
    assign uio_oe      = 8'b0;

endmodule
