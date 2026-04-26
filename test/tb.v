`timescale 1ns / 1ps

module tb ();

    // 1. Señales de estímulo
    reg        clk;
    reg        rst_n;
    reg        ena;
    reg  [7:0] ui_in;
    reg  [7:0] uio_in;
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    // 2. Parámetros de tiempo (50MHz y 115200 Baudios)
    localparam CLK_PERIOD = 20;              // 20ns = 50MHz
    localparam BIT_TIME   = 8680;            // 1s / 115200 = 8.68us = 8680ns

    // 3. Instancia del Proyecto (DUT)
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

    // 4. Generador de Reloj
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // 5. Tarea para enviar un byte por UART (8N1)
    task enviar_byte(input [7:0] data);
        integer i;
        begin
            ui_in[0] = 0; // Start Bit
            #(BIT_TIME);
            for (i = 0; i < 8; i = i + 1) begin
                ui_in[0] = data[i]; // LSB First
                #(BIT_TIME);
            end
            ui_in[0] = 1; // Stop Bit
            #(BIT_TIME);
            #(BIT_TIME); // Pausa entre bytes
        end
    endtask

    // 6. Flujo de la Simulación
    initial begin
        // Preparar archivos para GTKWave
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
        
        // Estado inicial
        rst_n = 0;
        ena = 1;
        ui_in = 8'hFF; // RX en IDLE (1)
        uio_in = 8'h00;

        // Reset
        #(CLK_PERIOD * 10);
        rst_n = 1;
        #(CLK_PERIOD * 10);

        $display("--- Iniciando carga de tiempo H00:00:02 ---");
        enviar_byte(8'h48); // 'H'
        enviar_byte(8'h30); // '0'
        enviar_byte(8'h30); // '0'
        enviar_byte(8'h3A); // ':'
        enviar_byte(8'h30); // '0'
        enviar_byte(8'h30); // '0'
        enviar_byte(8'h3A); // ':'
        enviar_byte(8'h30); // '0'
        enviar_byte(8'h32); // '2'

        #(BIT_TIME * 2);

        $display("--- Enviando comando de Inicio 'I' ---");
        enviar_byte(8'h49); // 'I'

        // Esperar a ver la respuesta en uo_out[2] (activo_o)
        wait(uo_out[2] == 1);
        $display(">>> Sistema ACTIVO detectado");

        // IMPORTANTE: Aquí la simulación tardaría mucho si CLK_FREQ es 50M.
        // Se asume que para el test se bajó el contador en Verilog.
        wait(uo_out[2] == 0);
        $display(">>> Sistema INACTIVO detectado (Fin del tiempo)");

        #(BIT_TIME * 10);
        $display("Simulación finalizada exitosamente.");
        $finish;
    end

endmodule