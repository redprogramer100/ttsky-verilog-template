module cmd_decoder (
    input  wire       clk_i,
    input  wire       reset_i,
    input  wire [7:0] rx_data,
    input  wire       rx_valid,
    output reg        start_o,
    output reg        reset_o,
    output reg [23:0] tiempo_o
);
    localparam IDLE = 2'd0;
    localparam T1   = 2'd1;
    localparam T2   = 2'd2;
    localparam T3   = 2'd3;

    reg [1:0]  state;
    reg [23:0] tiempo_buf;

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            state      <= IDLE;
            start_o    <= 0;
            reset_o    <= 0;
            tiempo_o   <= 0;
            tiempo_buf <= 0;
        end else begin
            // por defecto pulsos de un ciclo
            start_o <= 0;
            reset_o <= 0;

            if (rx_valid) begin
                case (state)
                    IDLE: begin
                        if (rx_data == 8'h52) begin      // 'R'
                            reset_o  <= 1;
                        end else if (rx_data == 8'h49) begin  // 'I'
                            start_o  <= 1;
                        end else if (rx_data == 8'h54) begin  // 'T'
                            state <= T1;
                        end
                    end
                    T1: begin
                        tiempo_buf[23:16] <= rx_data;
                        state <= T2;
                    end
                    T2: begin
                        tiempo_buf[15:8] <= rx_data;
                        state <= T3;
                    end
                    T3: begin
                        tiempo_buf[7:0] <= rx_data;
                        state <= IDLE;
                        // tiempo_o se actualiza el ciclo SIGUIENTE via always separado
                    end
                    default: state <= IDLE;
                endcase
            end

            // Cuando terminamos de recibir T3, un ciclo despues
            // tiempo_buf ya tiene el valor y emitimos start
            if (state == T3 && rx_valid) begin
                tiempo_o <= {tiempo_buf[23:8], rx_data};
                start_o  <= 1;
            end
        end
    end
endmodule
