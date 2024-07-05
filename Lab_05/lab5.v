`timescale 1ns / 1ps
/////////////////////////////////////////////////////////
module lab5(
  input clk,
  input reset_n,
  input [3:0] usr_btn,
  output [3:0] usr_led,
  output LCD_RS,
  output LCD_RW,
  output LCD_E,
  output [3:0] LCD_D
);

// turn off all the LEDs
assign usr_led = 4'b0000;
localparam [3:1] IDLE = 3'b001, FIBO = 3'b010, DISP = 3'b100;
wire btn_level, btn_pressed;
reg prev_btn_level;
reg [15:0] fib[24:0];//register for the fibonacci number
reg [31:0] timecount = 0;//count for 70,000,000
reg [7:0] fcounter = 0;//count 25 numbers
reg [7:0] dcounter1 = 0, dcounter2 = 0;
reg dipsdirection = 0;///0 for up, 1 for down
reg [2:0] state, next_state;//state for the FSM
reg [7:0] rowAcount, rowBcount;
wire [15:0] rowAcountchar, rowBcountchar;
reg[15:0] rowAnum, rowBnum;
wire [31:0] rowAnumchar, rowBnumchar;
reg [127:0] row_A = "Fibo #00 is 0000"; // Initialize the text of the first row.
reg [127:0] row_B = "Fibo #00 is 0000"; // Initialize the text of the second row.

int_to_hexchar2 rowAc(rowAcount,rowAcountchar);
int_to_hexchar2 rowBc(rowBcount,rowBcountchar);
int_to_hexchar4 rowAn(rowAnum,rowAnumchar);
int_to_hexchar4 rowBn(rowBnum,rowBnumchar);

LCD_module lcd0(
  .clk(clk),
  .reset(~reset_n),
  .row_A(row_A),
  .row_B(row_B),
  .LCD_E(LCD_E),
  .LCD_RS(LCD_RS),
  .LCD_RW(LCD_RW),
  .LCD_D(LCD_D)
);

debounce btn_db0(
  .clk(clk),
  .btn_input(usr_btn[3]),
  .btn_output(btn_level)
);


always @(posedge clk) begin//BUTTON LOGIC
  if (~reset_n)
    prev_btn_level <= 1;
  else
    prev_btn_level <= btn_level;
end
assign btn_pressed = (btn_level & ~prev_btn_level);


always@(posedge clk) begin
    if(~reset_n)
        state = IDLE;
    else 
        state = next_state;
end

always@(posedge clk) begin
    case(state)
        IDLE:   next_state = FIBO;
        FIBO:   next_state = (fcounter < 25) ? FIBO : DISP;
        DISP:   next_state = DISP;
        default: next_state = state;
    endcase
end

always @(posedge clk) begin//OUTPUT LOGIC
    case(state)
        IDLE:begin
            fcounter = 0;
            dcounter1 = 0;
            dipsdirection = 0;
            end
        FIBO:begin
            if(fcounter == 0)
                fib[fcounter] = 0;
            else if(fcounter == 1)
                fib[fcounter] = 1;
            else
                fib[fcounter] = fib[fcounter-1] + fib[fcounter-2];
            fcounter = fcounter + 1;
            end
        DISP:begin
            if(timecount < 70_000_000)
                timecount = timecount + 1;
            else begin
                dcounter2 = (dcounter1 < 24) ? dcounter1+1 : 0;
                rowAcount = dcounter1+1;
                rowBcount = dcounter2+1;
                rowAnum = fib[dcounter1];
                rowBnum = fib[dcounter2];
                timecount = 0;
                if(dipsdirection == 0)
                    dcounter1 = (dcounter1 < 24) ? dcounter1+1 : 0;
                else
                    dcounter1 = (dcounter1 > 0) ? dcounter1-1 : 24;
                row_A[79-:16] = rowAcountchar;
                row_B[79-:16] = rowBcountchar;
                row_A[31-:32] = rowAnumchar;
                row_B[31-:32] = rowBnumchar;
                end
            end
    endcase
    if(btn_pressed)
        dipsdirection = ~dipsdirection;
end

endmodule

module int_to_hexchar2(
    input [7:0]data_in,
    output [15:0]data_out
    );
    assign data_out[15-:8] = (data_in[7-:4] > 9) ? data_in[7-:4]-10+"A" : data_in[7-:4] + "0";
    assign data_out[7-:8] = (data_in[3-:4] > 9) ? data_in[3-:4]-10+"A" : data_in[3-:4] + "0";

endmodule

module int_to_hexchar4(
    input [15:0]data_in,
    output [31:0]data_out
    );
    assign data_out[31-:8] = (data_in[15-:4] > 9) ? data_in[15-:4]-10+"A" : data_in[15-:4] + "0";
    assign data_out[23-:8] = (data_in[11-:4] > 9) ? data_in[11-:4]-10+"A" : data_in[11-:4] + "0";
    assign data_out[15-:8] = (data_in[7-:4] > 9) ? data_in[7-:4]-10+"A" : data_in[7-:4] + "0";
    assign data_out[7-:8] = (data_in[3-:4] > 9) ? data_in[3-:4]-10+"A" : data_in[3-:4] + "0";
endmodule