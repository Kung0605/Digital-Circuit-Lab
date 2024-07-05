`timescale 1ns / 1ps
module lab4(
  input  clk,            // System clock at 100 MHz
  input  reset_n,        // System reset signal, in negative logic
  input  [3:0] usr_btn,  // Four user pushbuttons
  output reg [3:0] usr_led   // Four yellow LEDs
);  
    (*mark_debug = "true"*) wire [3 : 0] pressed;    
    debounce d0(clk, usr_btn[0], pressed[0]);
    debounce d1(clk, usr_btn[1], pressed[1]);
    debounce d2(clk, usr_btn[2], pressed[2]);
    debounce d3(clk, usr_btn[3], pressed[3]);
    (*mark_debug = "true"*) wire increase_counter, decrease_counter;
    assign increase_counter = pressed[1];
    assign decrease_counter = pressed[0];
    (*mark_debug = "true"*) reg signed [3 : 0] counter;
    always @(posedge clk) begin 
        if (~reset_n) 
            counter <= 4'b0;
        else if (decrease_counter)
            counter <= (counter == -8) ? counter : counter - 1;
        else if (increase_counter)
            counter <= (counter == 7) ? counter : counter + 1;
    end
    (*mark_debug = "true"*) reg [2 : 0] duty;
    (*mark_debug = "true"*) wire increase_duty, decrease_duty;
    assign increase_duty = pressed[3];
    assign decrease_duty = pressed[2];
    (*mark_debug = "true"*) reg [31 : 0] light, off;
    always  @(posedge clk) begin 
        if (~reset_n)
            duty <= 3'b0;
        else if (increase_duty)
            duty <= (duty == 3'd5) ? duty : duty + 1;
        else if (decrease_duty)
            duty <= (duty == 3'd0) ? duty : duty - 1;
    end
    always @(posedge clk) begin
        case (duty)
            3'd0 : light <= 0;
            3'd1 : light <= 32'd50000;
            3'd2 : light <= 32'd250000; 
            3'd3 : light <= 32'd500000;
            3'd4 : light <= 32'd750000;
            3'd5 : light <= 32'd1000000;
        endcase
    end
    (*mark_debug = "true"*) reg [31 : 0] timer;
    always @(posedge clk) begin 
        if (~reset_n)
            timer <= 32'd0;
        else if (timer == 32'd1000000)
            timer <= 32'd0;
        else 
            timer <= timer + 1;
    end
    always @(posedge clk) begin
        usr_led <= (timer < light) ? counter : 4'd0;
    end
endmodule