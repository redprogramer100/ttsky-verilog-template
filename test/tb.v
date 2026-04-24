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

    // Parámetros de tiempo (Basados en 100KHz y 10Kbps según el código actual)
    // Nota: Si cambias la frecuencia a 50MHz en el código real, 
    // estos tiempos deberán ajustarse proporcionalmente.
    localparam PERIODO_CLK = 10000;          // 100ns * 100 = 10us (100 KHz)
    localparam BIT_TIME    = 100000;         // 100us (10 Kbps)

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
            #(BIT_TIME); // Pausa entre comandos
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

        // 3. ENVIAR COMANDO 'I' (Iniciar con tiempo por defecto)
        // ASCII 'I' = 0x49
        $display("Enviando comando START ('I')...");
        enviar_byte(8'h49);
        
        #(BIT_TIME * 20); // Esperar a que el sistema procese y ver uo_out[1] (activo)

        // 4. ENVIAR COMANDO 'R' (Reset/Parar)
        // ASCII 'R' = 0x52
        $display("Enviando comando RESET ('R')...");
        enviar_byte(8'h52);

        #(BIT_TIME * 10);

        // 5. ENVIAR COMANDO 'T' + TIEMPO (Cargar 5 segundos)
        // ASCII 'T' = 0x54, seguido de 0x00, 0x00, 0x05
        $display("Enviando comando SET TIME ('T') para 5 segundos...");
        enviar_byte(8'h54); // Comando T
        enviar_byte(8'h00); // Byte alto
        enviar_byte(8'h00); // Byte medio
        enviar_byte(8'h05); // Byte bajo (5s)

        // 6. Observar el funcionamiento
        $display("Simulacion en curso. Observa las señales en el Waveform.");
        #(BIT_TIME * 100); 

        $display("Simulacion finalizada.");
    end

endmodule
