/*
 * uart_parser.v
 *
 * Interpreta comandos ASCII por UART:
 * 'R'/'S' -> Reset, 'I'/'X' -> Start, 'E'/'Y' -> Telemetría,
 * 'H'hh:mm:ss -> Carga de tiempo.
 * OPTIMIZACIÓN: Bloqueo de valores > 59 para minutos y segundos.
 */

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

    // Generador de pulso de error
    localparam PULSE_MAX = 25000000; // 0.5s a 50MHz
    reg [31:0] pulse_cnt;
    reg        pulse_active;

    // Estados de la FSM
    localparam IDLE = 4'd0;
    localparam H1   = 4'd1;
    localparam H2   = 4'd2;
    localparam C1   = 4'd3;
    localparam M1   = 4'd4;
    localparam M2   = 4'd5;
    localparam C2   = 4'd6;
    localparam S1   = 4'd7;
    localparam S2   = 4'd8;

    reg [3:0] state;
    reg [3:0] d1;

    // Función ASCII a número
    function [3:0] ascii_to_num;
        input [7:0] c;
        begin
            if (c >= 8'h30 && c <= 8'h39) // '0' a '9'
                ascii_to_num = c[3:0];
            else
                ascii_to_num = 4'd0;
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
            pulse_cnt     <= 32'd0;
            Enviando_o    <= 1'b0;
            d1            <= 4'd0;
        end else begin
            // Pulso de salida por defecto
            horaLista_o <= 1'b0;

            // Lógica de error
            if (pulse_active) begin
                if (pulse_cnt < PULSE_MAX) begin
                    pulse_cnt     <= pulse_cnt + 32'd1;
                    error_pulse_o <= 1'b1;
                end else begin
                    pulse_active  <= 1'b0;
                    pulse_cnt     <= 32'd0;
                    error_pulse_o <= 1'b0;
                end
            end

            // FSM de Comandos
            if (rx_valid) begin
                case (state)
                    IDLE: begin
                        case (rx_data)
                            8'h52: begin // 'R'
                                reset_pulse_o <= 1'b1;
                                hora_o <= 8'd0; min_o <= 8'd0; seg_o <= 8'd0;
                            end
                            8'h53: reset_pulse_o <= 1'b0; // 'S'
                            8'h49: init_pulse_o  <= 1'b1; // 'I'
                            8'h58: init_pulse_o  <= 1'b0; // 'X'
                            8'h48: state         <= H1;   // 'H'
                            8'h45: Enviando_o    <= 1'b1; // 'E'
                            8'h59: Enviando_o    <= 1'b0; // 'Y'
                            default: pulse_active <= 1'b1;
                        endcase
                    end

                    H1: begin
                        if (rx_data >= 8'h30 && rx_data <= 8'h39) begin
                            d1 <= ascii_to_num(rx_data);
                            state <= H2;
                        end else state <= IDLE;
                    end

                    H2: begin
                        if (rx_data >= 8'h30 && rx_data <= 8'h39) begin
                            hora_o <= (d1 * 4'd10) + ascii_to_num(rx_data);
                            state <= C1;
                        end else state <= IDLE;
                    end

                    C1: state <= (rx_data == 8'h3A) ? M1 : IDLE; // ':'

                    M1: begin
                        // OPTIMIZACIÓN: Solo permite decenas de '0' a '5'
                        if (rx_data >= 8'h30 && rx_data <= 8'h35) begin
                            d1 <= ascii_to_num(rx_data);
                            state <= M2;
                        end else state <= IDLE;
                    end

                    M2: begin
                        if (rx_data >= 8'h30 && rx_data <= 8'h39) begin
                            min_o <= (d1 * 4'd10) + ascii_to_num(rx_data);
                            state <= C2;
                        end else state <= IDLE;
                    end

                    C2: state <= (rx_data == 8'h3A) ? S1 : IDLE; // ':'

                    S1: begin
                        // OPTIMIZACIÓN: Solo permite decenas de '0' a '5'
                        if (rx_data >= 8'h30 && rx_data <= 8'h35) begin
                            d1 <= ascii_to_num(rx_data);
                            state <= S2;
                        end else state <= IDLE;
                    end

                    S2: begin
                        if (rx_data >= 8'h30 && rx_data <= 8'h39) begin
                            seg_o       <= (d1 * 4'd10) + ascii_to_num(rx_data);
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