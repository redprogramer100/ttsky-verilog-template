/*
 * uart_tx.v
 *
 * Standard UART Transmitter (8 data bits, 1 stop bit, no parity).
 *
 * This module converts an 8-bit parallel byte into a serial stream. 
 * It manages the insertion of the START bit (LOW) and the STOP bit (HIGH) 
 * while maintaining the correct baudrate timing based on the system clock.
 */
`default_nettype none
module uart_tx #(
    parameter CLK_FREQ = 50_000_000, 
    parameter BAUDRATE = 115200      
)(
    input  wire       clk_i,      
    input  wire       reset_i,    
    
    input  wire [7:0] data_i,     
    input  wire       valid_i,    
    output reg        ready_o,    
    output reg        tx_done_o,  
    output reg        tx_o        
);

    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUDRATE; // 434 para 50MHz

    localparam IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;

    reg [1:0] state;
    // OPTIMIZACIÓN: Para contar hasta 434, solo necesitamos 9 bits (2^9 = 512).
    reg [8:0] clk_cnt; 
    reg [2:0] bit_index;
    reg [7:0] data_reg;

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            state      <= IDLE;
            tx_o       <= 1'b1;  
            ready_o    <= 1'b1;  
            tx_done_o  <= 1'b0;
            clk_cnt    <= 9'd0;
            bit_index  <= 3'd0;
            data_reg   <= 8'd0;
        end else begin
            tx_done_o <= 1'b0;

            case (state)
                IDLE: begin
                    tx_o    <= 1'b1;
                    ready_o <= 1'b1;
                    
                    if (valid_i) begin
                        data_reg <= data_i; 
                        ready_o  <= 1'b0;   
                        clk_cnt  <= 9'd0;
                        state    <= START;
                    end
                end
                START: begin
                    tx_o <= 1'b0;
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 9'd1;
                    end else begin
                        clk_cnt   <= 9'd0;
                        bit_index <= 3'd0;
                        state     <= DATA;
                    end
                end
                DATA: begin
                    tx_o <= data_reg[bit_index]; 
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 9'd1;
                    end else begin
                        clk_cnt <= 9'd0;
                        if (bit_index < 3'd7) begin
                            bit_index <= bit_index + 3'd1;
                        end else begin
                            bit_index <= 3'd0;
                            state     <= STOP;
                        end
                    end
                end
                STOP: begin
                    tx_o <= 1'b1;
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 9'd1;
                    end else begin
                        clk_cnt   <= 9'd0;
                        tx_done_o <= 1'b1; 
                        state     <= IDLE;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule