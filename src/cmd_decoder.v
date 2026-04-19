module cmd_decoder (
    input  wire       clk_i,
    input  wire       reset_i,
    input  wire [7:0] rx_data,
    input  wire       rx_valid,
    output reg        start_o,
    output reg        reset_o,
    output reg [23:0] tiempo_o
);
    reg [1:0] state;
    reg       do_start;   // flag interno para emitir start un ciclo despues

    localparam IDLE = 2'd0;
    localparam T1   = 2'd1;
    localparam T2   = 2'd2;
    localparam T3   = 2'd3;

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            state    <= IDLE;
            start_o  <= 0;
            reset_o  <= 0;
            do_start <= 0;
            tiempo_o <= 0;
        end else begin
            start_o  <= 0;
            reset_o  <= 0;

            // Si el ciclo anterior pedimos start, lo emitimos ahora
            // (tiempo_o ya esta estable desde el ciclo anterior)
            if (do_start) begin
                do_start <= 0;
                start_o  <= 1;
            end

            if (rx_valid) begin
                case (state)
                    IDLE: begin
                        case (rx_data)
                            8'h52: reset_o <= 1;       // 'R' reset
                            8'h49: start_o <= 1;       // 'I' start inmediato
                            8'h54: state   <= T1;      // 'T' cargar tiempo
                            default: state <= IDLE;
                        endcase
                    end
                    T1: begin
                        tiempo_o[23:16] <= rx_data;
                        state <= T2;
                    end
                    T2: begin
                        tiempo_o[15:8] <= rx_data;
                        state <= T3;
                    end
                    T3: begin
                        tiempo_o[7:0] <= rx_data;
                        do_start <= 1;   // activar start en el SIGUIENTE ciclo
                        state    <= IDLE;
                    end
                    default: state <= IDLE;
                endcase
            end
        end
    end
endmodule
