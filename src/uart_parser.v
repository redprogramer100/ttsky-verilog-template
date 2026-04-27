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
    input  wire        clk_i,
    input  wire        reset_i,
    input  wire [7:0]  rx_data,
    input  wire        rx_valid,

    output reg         reset_pulse_o,
    output reg         init_pulse_o,
    output reg         error_pulse_o,
    output reg         horaLista_o,
    output reg  [7:0]  hora_o,
    output reg  [7:0]  min_o,
    output reg  [7:0]  seg_o,
    output reg         Enviando_o
);

    // OPTIMIZACIÓN: Contador de error reducido a 23 bits (ahorra Flip-Flops)
    localparam [22:0] PULSE_MAX = 23'd8000000; 
    reg [22:0] pulse_cnt;
    reg        pulse_active;

    // Estados de la FSM (4 bits)
    localparam IDLE = 4'd0, H1 = 4'd1, H2 = 4'd2, C1 = 4'd3, 
               M1 = 4'd4, M2 = 4'd5, C2 = 4'd6, S1 = 4'd7, S2 = 4'd8;

    reg [3:0] state;
    reg [3:0] d1;

    // Función optimizada: solo toma los 4 bits bajos del ASCII
    function [3:0] ascii_to_num;
        input [7:0] c;
        begin
            ascii_to_num = c[3:0];
        end
    endfunction

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            state         <= IDLE;
            hora_o        <= 8'd0;
            min_o         <= 8'd0;
            seg_o         <= 8'd0;
            reset_pulse_o <= 1'b0;
            init_pulse_o  <= 1'b0;
            error_pulse_o <= 1'b0;
            horaLista_o   <= 1'b0;
            pulse_active  <= 1'b0;
            pulse_cnt     <= 23'd0;
            Enviando_o    <= 1'b0;
            d1            <= 4'd0;
        end else begin
            // Pulso por defecto
            horaLista_o <= 1'b0;

            // Lógica de pulso de error (Visualización en uo_out)
            if (pulse_active) begin
                if (pulse_cnt < PULSE_MAX) begin
                    pulse_cnt     <= pulse_cnt + 23'd1;
                    error_pulse_o <= 1'b1;
                end else begin
                    pulse_active  <= 1'b0;
                    pulse_cnt     <= 23'd0;
                    error_pulse_o <= 1'b0;
                end
            end

            // FSM de Procesamiento de Comandos
            if (rx_valid) begin
                case (state)
                    IDLE: begin
                        case (rx_data)
                            8'h52: begin // 'R' (Reset Interno)
                                reset_pulse_o <= 1'b1;
                                {hora_o, min_o, seg_o} <= 24'd0;
                            end
                            8'h53: reset_pulse_o <= 1'b0; // 'S' (Stop Reset)
                            8'h49: init_pulse_o  <= 1'b1; // 'I' (Start)
                            8'h58: init_pulse_o  <= 1'b0; // 'X' (Stop Start)
                            8'h48: state         <= H1;   // 'H' (Header Tiempo)
                            8'h45: Enviando_o    <= 1'b1; // 'E' (Enable Telemetría)
                            8'h59: Enviando_o    <= 1'b0; // 'Y' (Disable Telemetría)
                            default: begin
                                // Cualquier otro caracter activa el error
                                if (!pulse_active) pulse_active <= 1'b1;
                            end
                        endcase
                    end

                    H1: begin // Decena de Hora
                        if (rx_data >= 8'h30 && rx_data <= 8'h39) begin
                            d1 <= ascii_to_num(rx_data);
                            state <= H2;
                        end else state <= IDLE;
                    end

                    H2: begin // Unidad de Hora
                        if (rx_data >= 8'h30 && rx_data <= 8'h39) begin
                            // OPTIMIZACIÓN: (d1 * 10) -> (d1<<3) + (d1<<1)
                            hora_o <= (d1 << 3) + (d1 << 1) + ascii_to_num(rx_data);
                            state <= C1;
                        end else state <= IDLE;
                    end

                    C1: state <= (rx_data == 8'h3A) ? M1 : IDLE; // ':'

                    M1: begin // Decena de Minutos (0-5)
                        if (rx_data >= 8'h30 && rx_data <= 8'h35) begin
                            d1 <= ascii_to_num(rx_data);
                            state <= M2;
                        end else state <= IDLE;
                    end

                    M2: begin // Unidad de Minutos
                        if (rx_data >= 8'h30 && rx_data <= 8'h39) begin
                            min_o <= (d1 << 3) + (d1 << 1) + ascii_to_num(rx_data);
                            state <= C2;
                        end else state <= IDLE;
                    end

                    C2: state <= (rx_data == 8'h3A) ? S1 : IDLE; // ':'

                    S1: begin // Decena de Segundos (0-5)
                        if (rx_data >= 8'h30 && rx_data <= 8'h35) begin
                            d1 <= ascii_to_num(rx_data);
                            state <= S2;
                        end else state <= IDLE;
                    end

                    S2: begin // Unidad de Segundos
                        if (rx_data >= 8'h30 && rx_data <= 8'h39) begin
                            seg_o       <= (d1 << 3) + (d1 << 1) + ascii_to_num(rx_data);
                            horaLista_o <= 1'b1; // Notifica que el tiempo es válido
                        end
                        state <= IDLE;
                    end

                    default: state <= IDLE;
                endcase
            end
        end
    end

endmodule