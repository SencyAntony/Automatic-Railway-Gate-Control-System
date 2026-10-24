`timescale 1ns/1ps

module tb_railway_gate;

    reg clock = 1'b0;
    always #10 clock = ~clock;      // 50 MHz

    // Every input starts at a defined value (gate starts open)
    reg reset_n         = 1'b0;
    reg sensor_approach = 1'b1;
    reg sensor_exit     = 1'b1;
    reg limit_open      = 1'b0;
    reg limit_closed    = 1'b1;

    wire       motor_close;
    wire       motor_open;
    wire       buzzer;
    wire       fault;
    wire [2:0] gate_state;

    railway_gate #(
        .TIMEOUT_CYCLES(40),
        .COUNTER_WIDTH(8)
    ) device_under_test (
        .clock(clock),
        .reset_n(reset_n),
        .sensor_approach(sensor_approach),
        .sensor_exit(sensor_exit),
        .limit_open(limit_open),
        .limit_closed(limit_closed),
        .motor_close(motor_close),
        .motor_open(motor_open),
        .buzzer(buzzer),
        .fault(fault),
        .gate_state(gate_state)
    );

    task wait_clock_cycles(input integer number_of_cycles);
        begin repeat (number_of_cycles) @(posedge clock); end
    endtask

    task apply_reset;
        begin
            reset_n         = 1'b0;
            sensor_approach = 1'b1;
            sensor_exit     = 1'b1;
            limit_open      = 1'b0;
            limit_closed    = 1'b1;
            wait_clock_cycles(3);
            reset_n = 1'b1;
            wait_clock_cycles(5);
        end
    endtask

    task pulse_approach;
        begin
            sensor_approach = 1'b0; wait_clock_cycles(6);
            sensor_approach = 1'b1; wait_clock_cycles(4);
        end
    endtask

    task pulse_exit;
        begin
            sensor_exit = 1'b0; wait_clock_cycles(6);
            sensor_exit = 1'b1; wait_clock_cycles(4);
        end
    endtask

    initial begin
        $dumpfile("tb_railway_gate.vcd");
        $dumpvars(0, tb_railway_gate);

        // Case 1: normal cycle
        apply_reset;
        pulse_approach;
        limit_open   = 1'b1; wait_clock_cycles(6);
        limit_closed = 1'b0; wait_clock_cycles(6);
        pulse_exit;
        limit_closed = 1'b1; wait_clock_cycles(6);
        limit_open   = 1'b0; wait_clock_cycles(6);

        // Case 2: timeout while closing
        apply_reset;
        pulse_approach;
        wait_clock_cycles(60);

        // Case 3: both limit switches active
        apply_reset;
        limit_closed = 1'b0; wait_clock_cycles(8);

        // Case 4: new train while opening, gate closes again
        apply_reset;
        pulse_approach;
        limit_open   = 1'b1; wait_clock_cycles(6);
        limit_closed = 1'b0; wait_clock_cycles(6);
        pulse_exit;
        limit_closed = 1'b1; wait_clock_cycles(6);
        pulse_approach;
        wait_clock_cycles(10);

        // Case 5: reset during operation
        apply_reset;
        pulse_approach;
        apply_reset;

        $finish;
    end

endmodule
