`timescale 1ns / 1ps

module tb ();

    // Señales del sistema
    reg        clk;
    reg        rst_n;
    reg        ena;
    reg  [7:0] ui_in;
    reg  [7:0] uio_in;
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    // Instancia del proyecto (DUT)
    // Conectado exactamente a tu top tt_um actualizado
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

    // Parámetros de tiempo reales (50 MHz y 115200 Baudios)
    localparam PERIODO_CLK = 20;             // 20ns = 50 MHz
    localparam BIT_TIME    = 8680;           // 1/115200 ≈ 8.68us = 8680ns

    // Generador de Reloj
    initial clk = 0;
    always #(PERIODO_CLK/2) clk = ~clk;

    // Tarea para enviar un byte por UART (Protocolo 8N1)
    task enviar_byte(input [7:0] data);
        integer i;
        begin
            ui_in[0] = 0; // Bit de Inicio (Start Bit)
            #(BIT_TIME);
            for (i = 0; i < 8; i = i + 1) begin
                ui_in[0] = data[i]; // Bits de datos (LSB primero)
                #(BIT_TIME);
            end
            ui_in[0] = 1; // Bit de Parada (Stop Bit)
            #(BIT_TIME);
            #(BIT_TIME); // Pausa entre bytes
        end
    endtask

    // Secuencia de Simulación
    initial begin
        // 1. Inicialización de señales
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
        
        rst_n = 0;
        ena = 1;
        ui_in = 8'hFF; // Línea UART en IDLE (alto)
        uio_in = 8'h00;

        // 2. Liberar Reset
        #(PERIODO_CLK * 10);
        rst_n = 1;
        #(PERIODO_CLK * 10);

        // 3. CARGAR TIEMPO 'H' (Formato ASCII HH:MM:SS)
        // Ejemplo: H00:00:02 (2 segundos)
        $display("Configurando tiempo: H00:00:02...");
        enviar_byte("H");
        enviar_byte("0"); enviar_byte("0"); enviar_byte(":");
        enviar_byte("0"); enviar_byte("0"); enviar_byte(":");
        enviar_byte("0"); enviar_byte("2");

        // 4. HABILITAR TELEMETRÍA 'E' Y EMPEZAR 'I'
        $display("Enviando ENABLE ('E') y START ('I')...");
        enviar_byte("E"); 
        enviar_byte("I");
        
        // Esperar a que el timer se active (uo_out[2])
        wait(uo_out[2] == 1);
        $display("Timer activo detectado.");

        // 5. ESPERAR FINALIZACIÓN
        // El timer dura 2 segundos, esperamos un poco más para ver la trama TX
        #(BIT_TIME * 300); 

        // 6. ENVIAR RESET 'R' PARA LIMPIAR
        $display("Enviando comando RESET ('R')...");
        enviar_byte("R");
        enviar_byte("S"); // Bajar el pulso de reset según tu parser

        #(BIT_TIME * 20);

        $display("Simulacion finalizada. Revisa el archivo tb.vcd.");
        $finish;
    end

endmodule