`timescale 1ns / 1ps

module flow_control (
    input clk,
    input reset_n,
    input [31:0] rng_input,
    input [3:0] usr_btn,
    input [3:0] usr_sw,
    input [7:0] state_input,
    input [4*4-1:0] score_input,
    input score_inc_input,
    output [7:0] control_output,
    output reg start_output,
    output over_output,
    output [3:0] btn_pressed_output
);
localparam  NONE       = 0,
            INIT       = 1, 
            GEN        = 2, 
            WAIT       = 3,
            LEFT       = 4,
            RIGHT      = 5, 
            DOWN       = 6, 
            DROP       = 7,
            HOLD       = 8, 
            ROTATE     = 9,
            ROTATE_REV = 10, 
            BAR        = 11,
            PCHECK     = 12, 
            DCHECK     = 13, 
            MCHECK     = 14, 
            HCHECK     = 15,
            CPREP      = 16, 
            CLEAR      = 17, 
            BPLACE     = 18, 
            END        = 19;

// Button debounce module instances
wire [3:0] debounced_btn_level;
debounce btn_db0(
  .clk(clk),
  .btn_input(usr_btn[0]),
  .btn_output(debounced_btn_level[0])
);
debounce btn_db1(
  .clk(clk),
  .btn_input(usr_btn[1]),
  .btn_output(debounced_btn_level[1])
);
debounce btn_db2(
  .clk(clk),
  .btn_input(usr_btn[2]),
  .btn_output(debounced_btn_level[2])
);
debounce btn_db3(
  .clk(clk),
  .btn_input(usr_btn[3]),
  .btn_output(debounced_btn_level[3])
);
reg [3:0] btn_pressed;
assign btn_pressed_output = btn_pressed;
reg [3:0] prev_btn_level;
integer i;
always @(posedge clk) begin 
  if (~reset_n)
    btn_pressed <= 0;
  else begin 
    for (i = 0; i < 4; i = i + 1)
      btn_pressed[i] <= ~prev_btn_level[i] & debounced_btn_level[i];
  end
end
always @(posedge clk) begin 
  if (~reset_n)
    prev_btn_level <= 0;
  else 
    prev_btn_level <= debounced_btn_level;
end

// Switch logic
reg [3:0] prev_sw;
wire [3:0] press_sw;
always @(posedge clk)
    prev_sw <= usr_sw;
assign press_sw = usr_sw^prev_sw;

// Control logic parameters
localparam SEC_TICK = 25000000;
localparam MSEC_TICK = 25000;
localparam DOWN_TICK = SEC_TICK;
reg [$clog2(DOWN_TICK)+2:0] down_cnt,down_tick;
reg [7:0] next_state = NONE;
wire during;

// Start and end logic
assign during = (start_output) && (~over_output); //1 if start and not over
assign over_output = (start_output) && (state_input==END);
always @(posedge clk) begin
    if(~reset_n)
        start_output <= 0;
    else if(next_state == INIT || next_state == END)
        start_output <= ~over_output;
    else    
        start_output <= start_output;
end

// Falling down logic
always @(posedge clk) begin
    if(~reset_n || ~during)
        down_tick <= DOWN_TICK;
    else if(down_tick >= MSEC_TICK && score_inc_input && ~usr_sw[3])
        down_tick <= down_tick * 9 / 10;
end
always @(posedge clk)begin
    if(~reset_n || ~during)
        down_cnt <= 0;
    else if(next_state == DOWN)
        if(down_cnt < down_tick)
            down_cnt <=0;
        else    
            down_cnt <= down_cnt - down_tick;
    else    
        down_cnt <= down_cnt + 1;
end

// State transition logic
always @(*) begin
    next_state = NONE; //do nothing
    if(reset_n) begin
        if(~during) begin
            if( |debounced_btn_level || |press_sw)
                next_state = over_output? END : INIT;
        end
        else begin
            if(down_cnt >= down_tick)
                next_state = DOWN;
            if(btn_pressed[0])
                next_state = RIGHT;
            if(btn_pressed[1])
                next_state = DOWN;
            if(btn_pressed[2])
                next_state = ROTATE;
            if(btn_pressed[3])
                next_state = LEFT;
            if(press_sw[0])
                next_state = DROP;
            if(press_sw[1])
                next_state = HOLD;
            if(press_sw[2])
                next_state = ROTATE_REV;
        end
    end
end

// Queue to manage the states
localparam QSIZE = 16;
reg [$clog2(QSIZE):0] cnt = 0;
reg [7:0] queue [0:QSIZE];
assign control_output = queue[0];

always @(posedge clk) begin
    if(~reset_n) begin
        cnt <= 0;
        for(i=0; i<=QSIZE; i=i+1)
            queue[i] <= NONE;
    end else if(state_input == WAIT) begin
        if(cnt==0) begin
            queue[0] <= next_state;
        end else begin
            cnt <= cnt - (next_state==NONE);
            for(i=0; i<=QSIZE; i=i+1) 
                queue[i] <= (i==cnt)? next_state : ((i==QSIZE) ? NONE : queue[i+1]);
        end
    end else begin 
        cnt <= cnt + (next_state!=NONE);
        queue[cnt] <= next_state;
    end
end

endmodule
