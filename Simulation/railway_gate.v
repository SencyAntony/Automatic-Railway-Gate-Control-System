// Simple Automatic Railway Gate Controller
// Educational prototype - not a certified railway safety system.
// All sensors and limit switches are active-low.
`timescale 1ns/1ps

module railway_gate #(
    parameter TIMEOUT_CYCLES = 250_000_000,   // 5 seconds at 50 MHz
    parameter COUNTER_WIDTH  = 28
)(
    input  wire       clock,
    input  wire       reset_n,
    input  wire       sensor_approach,
    input  wire       sensor_exit,
    input  wire       limit_open,
    input  wire       limit_closed,
    output reg        motor_close,
    output reg        motor_open,
    output reg        buzzer,
    output reg        fault,
    output wire [2:0] gate_state
);

    localparam [2:0] STATE_OPEN    = 3'd0,
                     STATE_CLOSING = 3'd1,
                     STATE_CLOSED  = 3'd2,
                     STATE_OPENING = 3'd3,
                     STATE_FAULT   = 3'd4;

    // Two-stage synchronisers (reset to idle level = high)
    reg [1:0] synchroniser_approach;
    reg [1:0] synchroniser_exit;
    reg [1:0] synchroniser_limit_open;
    reg [1:0] synchroniser_limit_closed;

    always @(posedge clock or negedge reset_n) begin
        if (!reset_n) begin
            synchroniser_approach     <= 2'b11;
            synchroniser_exit         <= 2'b11;
            synchroniser_limit_open   <= 2'b11;
            synchroniser_limit_closed <= 2'b11;
        end else begin
            synchroniser_approach     <= {synchroniser_approach[0],     sensor_approach};
            synchroniser_exit         <= {synchroniser_exit[0],         sensor_exit};
            synchroniser_limit_open   <= {synchroniser_limit_open[0],   limit_open};
            synchroniser_limit_closed <= {synchroniser_limit_closed[0], limit_closed};
        end
    end

    // Active-high internal signals
    wire train_approaching = ~synchroniser_approach[1];
    wire train_exiting     = ~synchroniser_exit[1];
    wire gate_is_open      = ~synchroniser_limit_open[1];
    wire gate_is_closed    = ~synchroniser_limit_closed[1];

    reg [2:0]               current_state;
    reg [2:0]               next_state;
    reg [COUNTER_WIDTH-1:0] timeout_counter;

    wire timeout_reached   = (timeout_counter == TIMEOUT_CYCLES - 1);
    wire invalid_limits    = gate_is_open & gate_is_closed;

    assign gate_state = current_state;

    // State register and timeout counter
    always @(posedge clock or negedge reset_n) begin
        if (!reset_n) begin
            current_state   <= STATE_OPEN;
            timeout_counter <= 0;
        end else begin
            current_state <= next_state;
            if (current_state != next_state)
                timeout_counter <= 0;
            else if (current_state == STATE_CLOSING || current_state == STATE_OPENING)
                timeout_counter <= timeout_counter + 1'b1;
            else
                timeout_counter <= 0;
        end
    end

    // Next-state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            STATE_OPEN: begin
                if (invalid_limits)         next_state = STATE_FAULT;
                else if (train_approaching) next_state = STATE_CLOSING;
            end
            STATE_CLOSING: begin
                if (invalid_limits | timeout_reached) next_state = STATE_FAULT;
                else if (gate_is_closed)              next_state = STATE_CLOSED;
            end
            STATE_CLOSED: begin
                if (invalid_limits | ~gate_is_closed)       next_state = STATE_FAULT;
                else if (train_exiting & ~train_approaching) next_state = STATE_OPENING;
            end
            STATE_OPENING: begin
                if (invalid_limits | timeout_reached) next_state = STATE_FAULT;
                else if (train_approaching)           next_state = STATE_CLOSING;
                else if (gate_is_open)                next_state = STATE_OPEN;
            end
            STATE_FAULT: next_state = STATE_FAULT;
            default:     next_state = STATE_FAULT;
        endcase
    end

    // Registered outputs
    always @(posedge clock or negedge reset_n) begin
        if (!reset_n) begin
            motor_close <= 1'b0;
            motor_open  <= 1'b0;
            buzzer      <= 1'b0;
            fault       <= 1'b0;
        end else begin
            motor_close <= (next_state == STATE_CLOSING);
            motor_open  <= (next_state == STATE_OPENING);
            buzzer      <= (next_state != STATE_OPEN);
            fault       <= (next_state == STATE_FAULT);
        end
    end

endmodule
