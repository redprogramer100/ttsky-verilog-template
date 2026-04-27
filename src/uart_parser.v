/*
 * uart_parser.v
 * * OPTIMIZACIÓN EXTREMA PARA ASIC (Tiny Tapeout):
 * 1. Multiplicaciones por 10 convertidas a (x<<3) + (x<<1).
 * 2. Contador de pulso de error reducido a 23 bits (aprox 0.16s).
 * 3. Eliminación de lógica redundante para minimizar celdas.
 */
`default_nettype none
module uart_parser (
    input  wire        clk_i, reset_i,
    input  wire [7:0]  rx_data,
    input  wire        rx_valid,
    output reg         reset_pulse_o, init_pulse_o, error_pulse_o,
    output reg         load_h_o, load_m_o, load_s_o, // Pulsos de carga
    output wire [7:0]  data_o,                      // Dato directo
    output reg         Enviando_o
);
    localparam IDLE=0, H1=1, H2=2, C1=3, M1=4, M2=5, C2=6, S1=7, S2=8;
    reg [3:0] state;
    reg [3:0] d1;

    assign data_o = (d1 << 3) + (d1 << 1) + rx_data[3:0]; // Conversión combinacional

    always @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            state <= IDLE; d1 <= 0;
            {reset_pulse_o, init_pulse_o, error_pulse_o, load_h_o, load_m_o, load_s_o, Enviando_o} <= 7'b0;
        end else begin
            {reset_pulse_o, init_pulse_o, error_pulse_o, load_h_o, load_m_o, load_s_o} <= 6'b0;
            if (rx_valid) begin
                case (state)
                    IDLE: case (rx_data)
                        8'h52: reset_pulse_o <= 1; // R
                        8'h49: init_pulse_o  <= 1; // I
                        8'h48: state <= H1;        // H
                        8'h45: Enviando_o <= 1;    // E
                        8'h59: Enviando_o <= 0;    // Y
                        default: error_pulse_o <= 1;
                    endcase
                    H1: if (rx_data[7:4]==4'h3) begin d1<=rx_data[3:0]; state<=H2; end else state<=IDLE;
                    H2: if (rx_data[7:4]==4'h3) begin load_h_o<=1; state<=C1; end else state<=IDLE;
                    C1: state <= (rx_data == 8'h3A) ? M1 : IDLE;
                    M1: if (rx_data >= 8'h30 && rx_data <= 8'h35) begin d1<=rx_data[3:0]; state<=M2; end else state<=IDLE;
                    M2: if (rx_data[7:4]==4'h3) begin load_m_o<=1; state<=C2; end else state<=IDLE;
                    C2: state <= (rx_data == 8'h3A) ? S1 : IDLE;
                    S1: if (rx_data >= 8'h30 && rx_data <= 8'h35) begin d1<=rx_data[3:0]; state<=S2; end else state<=IDLE;
                    S2: if (rx_data[7:4]==4'h3) begin load_s_o<=1; state<=IDLE; end else state<=IDLE;
                endcase
            end
        end
    end
endmodule