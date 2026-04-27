/*
 * uart_parser.v
 * * OPTIMIZACIÓN EXTREMA PARA ASIC (Tiny Tapeout):
 * 1. Multiplicaciones por 10 convertidas a (x<<3) + (x<<1).
 * 2. Contador de pulso de error reducido a 23 bits (aprox 0.16s).
 * 3. Eliminación de lógica redundante para minimizar celdas.
 */
`default_nettype none
module uart_parser #(
    parameter CLK_FREQ = 50000000
)(
    input  wire        clk_i, reset_i,
    input  wire [7:0]  rx_data,
    input  wire        rx_valid,
    output reg         reset_pulse_o, init_pulse_o, error_pulse_o,
    output reg         horaLista_o,
    output reg  [7:0]  hora_o, min_o, seg_o,
    output reg         Enviando_o
);

    localparam IDLE = 4'd0, H1 = 4'd1, H2 = 4'd2, C1 = 4'd3, 
               M1 = 4'd4, M2 = 4'd5, C2 = 4'd6, S1 = 4'd7, S2 = 4'd8;

    reg [3:0] state;
    reg [3:0] d1;

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            state <= IDLE; 
            {hora_o, min_o, seg_o} <= 24'd0;
            {reset_pulse_o, init_pulse_o, error_pulse_o, horaLista_o, Enviando_o} <= 5'b0;
            d1 <= 4'd0;
        end else begin
            // Pulsos de un solo ciclo para ahorrar lógica de contadores
            {reset_pulse_o, init_pulse_o, error_pulse_o, horaLista_o} <= 4'b0;

            if (rx_valid) begin
                case (state)
                    IDLE: begin
                        case (rx_data)
                            8'h52: begin reset_pulse_o <= 1'b1; {hora_o, min_o, seg_o} <= 24'd0; end // 'R'
                            8'h53: reset_pulse_o <= 1'b0; // 'S'
                            8'h49: init_pulse_o  <= 1'b1; // 'I'
                            8'h58: init_pulse_o  <= 1'b0; // 'X'
                            8'h48: state         <= H1;   // 'H'
                            8'h45: Enviando_o    <= 1'b1; // 'E'
                            8'h59: Enviando_o    <= 1'b0; // 'Y'
                            default: error_pulse_o <= 1'b1;
                        endcase
                    end

                    H1: begin
                        if (rx_data >= 8'h30 && rx_data <= 8'h39) begin d1 <= rx_data[3:0]; state <= H2; end 
                        else state <= IDLE;
                    end

                    H2: begin
                        if (rx_data >= 8'h30 && rx_data <= 8'h39) begin 
                            hora_o <= (d1 << 3) + (d1 << 1) + rx_data[3:0]; 
                            state <= C1; 
                        end else state <= IDLE;
                    end

                    C1: begin state <= (rx_data == 8'h3A) ? M1 : IDLE; end

                    M1: begin
                        if (rx_data >= 8'h30 && rx_data <= 8'h35) begin d1 <= rx_data[3:0]; state <= M2; end 
                        else state <= IDLE;
                    end

                    M2: begin
                        if (rx_data >= 8'h30 && rx_data <= 8'h39) begin 
                            min_o <= (d1 << 3) + (d1 << 1) + rx_data[3:0]; 
                            state <= C2; 
                        end else state <= IDLE;
                    end

                    C2: begin state <= (rx_data == 8'h3A) ? S1 : IDLE; end

                    S1: begin
                        if (rx_data >= 8'h30 && rx_data <= 8'h35) begin d1 <= rx_data[3:0]; state <= S2; end 
                        else state <= IDLE;
                    end

                    S2: begin
                        if (rx_data >= 8'h30 && rx_data <= 8'h39) begin 
                            seg_o <= (d1 << 3) + (d1 << 1) + rx_data[3:0]; 
                            horaLista_o <= 1'b1; 
                        end 
                        state <= IDLE;
                    end

                    default: state <= IDLE;
                endcase
            end
        end
    end
endmodule