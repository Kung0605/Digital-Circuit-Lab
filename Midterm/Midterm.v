`timescale 1ns / 1ps

module midterm(
  input clk,
  input reset_n,
  input [3:0] usr_btn,
  output [3:0] usr_led,
  output LCD_RS,
  output LCD_RW,
  output LCD_E,
  output [3:0] LCD_D
);
//FSM transition
localparam [2 : 0]  INIT = 0,
                    SET_ANSWER = 1,
                    SELECT_ANSWER = 2,
                    GUESSING = 3,
                    CHECK = 4,
                    FINISH = 5,
                    SET_ERROR = 6,
                    GUESS_ERROR = 7;
reg [2 : 0] state, next_state;
wire [3 : 0] btn, btn_pressed;
wire answer_hit;
reg [2 : 0] guess_count;
reg [3 : 0] reg_btn;
wire set_error, guess_error;
always @(posedge clk) begin
    if (~reset_n)
        state <= INIT;
    else 
        state <= next_state;
end                           

always @(*) begin
    case (state)
        INIT : next_state = btn_pressed[3] ? SET_ANSWER : INIT;
        SET_ANSWER :if (~btn_pressed[0])
                        next_state = SET_ANSWER;
                    else 
                        next_state = set_error ? SET_ERROR : SELECT_ANSWER;
        SELECT_ANSWER : next_state = btn_pressed[3] ? GUESSING : SELECT_ANSWER;
        GUESSING :  if (~btn_pressed[0])
                        next_state = GUESSING;
                    else 
                        next_state = guess_error ? GUESS_ERROR : CHECK;
        CHECK : if (btn_pressed[3] & answer_hit)
                        next_state = FINISH;
                else if (btn_pressed[3] & guess_count == 3)
                    next_state = FINISH;
                else if (btn_pressed[3] & guess_count  < 3)
                    next_state = GUESSING;
                else 
                    next_state = CHECK;
        FINISH : next_state = btn_pressed[3] ? SET_ANSWER : FINISH;
        SET_ERROR : next_state = btn_pressed[3] ? SET_ANSWER : SET_ERROR;
        GUESS_ERROR : next_state = btn_pressed[3] ? GUESSING : GUESS_ERROR;
        default : next_state = INIT;
    endcase
end

//Display control
reg [127:0] row_A, row_B; 
(* mark_debug = "true"*)reg [31 : 0] answer, guess_answer;
reg [1 : 0] set_count;
reg [1 : 0] guess_bit_count;
reg [3 : 0] chosen_bit, guess_chosen_bit;
reg [2 : 0] count_A, count_B; 
integer i;
always @(posedge clk) begin
    case (state)
        INIT :  begin
            row_A <= "WELCOME! 0652021";
            row_B <= "PRESS BTN3 START";
        end 
        SET_ANSWER : begin 
            row_A <= {"9876543210  ", answer};
            for (i = 0; i < 16; i = i + 1) begin
                if (i == chosen_bit | i == set_count)
                    row_B[i * 8 +: 8] <= "^";
                else 
                    row_B[i * 8 +: 8] <= " ";
            end
        end
        SELECT_ANSWER : begin
            row_A <= "ANSWER IS SET TO";
            row_B <= {"      ", answer, "      "};
        end
        GUESSING : begin
            row_A <= {"9876543210  ", guess_answer};
            for (i = 0; i < 16; i = i + 1) begin
                if (i == guess_chosen_bit | i == guess_bit_count)
                    row_B[i * 8 +: 8] <= "^";
                else 
                    row_B[i * 8 +: 8] <= " ";
            end
        end
        CHECK : begin
            row_A <= {"GUESS IS:   ", guess_answer};
            row_B <= {"      ", count_A + "0", "A", count_B + "0", "B", "      "}; 
        end
        FINISH : begin
            if (answer_hit) begin
                row_A <= "  CONGRULATE!!  ";
                row_B <= {" ", 4 - guess_count + "0", " CHANCE LEFT! "};
            end
            else begin
                row_A <= "    FAILED!!    ";
                row_B <= {"ANSWER IS: ", answer, " "};
            end
        end
        SET_ERROR : begin
            row_A <= "ERROR!RESETINPUT";
            row_B <= "PRESS BTN3 RESET";
        end
        GUESS_ERROR : begin
            row_A <= "ERROR!RESETINPUT";
            row_B <= "PRESS BTN3 RESET";
        end
        default : begin
            row_A <= "ERROR!RESETINPUT";
            row_B <= "PRESS BTN3 RESET";
        end
    endcase
end
//Input taking at setting answer
reg reset_answer;
always @(posedge clk) begin
    if (~reset_n | reset_answer)
        chosen_bit <= 4'd10;
    else if (state != SET_ANSWER)
        chosen_bit <= chosen_bit;
    else if (btn_pressed[3]) 
        chosen_bit <= (chosen_bit == 4'd15 ? chosen_bit : chosen_bit + 4'd1); 
    else if (btn_pressed[2])
        chosen_bit <= (chosen_bit == 4'd6 ? chosen_bit : chosen_bit - 4'd1);
    else 
        chosen_bit <= chosen_bit;
end 

always @(posedge clk) begin
    if (state != SET_ANSWER & next_state == SET_ANSWER)
        reset_answer <= 1'b1;
    else 
        reset_answer <= 1'b0;
end 

always @(posedge clk) begin
    if (~reset_n | reset_answer) begin
        set_count <= 2'd0;
        answer <= "XXXX";
    end
    else if (state != SET_ANSWER) begin
        set_count <= set_count;
        answer <= answer;
    end
    else if (btn_pressed[1]) begin
        set_count <= set_count + 2'd1;
        answer[set_count * 8 +: 8] <= row_A[chosen_bit * 8 +: 8];
    end
    else begin
        set_count <= set_count;
        answer <= answer;
    end
end

//Input taking at guess answer
reg reset_guess_answer;
always @(posedge clk) begin
    if (~reset_n | reset_guess_answer)
        guess_chosen_bit <= 4'd10;
    else if (state != GUESSING)
        guess_chosen_bit <= guess_chosen_bit;
    else if (btn_pressed[3]) 
        guess_chosen_bit <= (guess_chosen_bit == 4'd15 ? guess_chosen_bit : guess_chosen_bit + 4'd1); 
    else if (btn_pressed[2])
        guess_chosen_bit <= (guess_chosen_bit == 4'd6 ? guess_chosen_bit : guess_chosen_bit - 4'd1);
    else 
        guess_chosen_bit <= guess_chosen_bit;
end

always @(posedge clk) begin
    if (state != GUESSING & next_state == GUESSING)
        reset_guess_answer <= 1'b1;
    else
        reset_guess_answer <= 1'b0;
end
always @(posedge clk) begin
    if (~reset_n | reset_guess_answer) begin
        guess_bit_count <= 2'd0;
        guess_answer <= "XXXX";
    end
    else if (state != GUESSING) begin
        guess_bit_count <= guess_bit_count;
        guess_answer <= guess_answer;
    end
    else if (btn_pressed[1]) begin
        guess_bit_count <= guess_bit_count + 2'd1;
        guess_answer[guess_bit_count * 8 +: 8] <= row_A[guess_chosen_bit * 8 +: 8];
    end
    else begin
        guess_bit_count <= guess_bit_count;
        guess_answer <= guess_answer;
    end
end

always @(posedge clk) begin
    if (~reset_n | state == SET_ANSWER)
        guess_count <= 2'd0;
    else if (state != GUESSING)
        guess_count <= guess_count;
    else begin
        if (btn_pressed[0] & next_state == CHECK)
            guess_count <= guess_count + 2'd1;
        else
            guess_count <= guess_count;
    end
end 
//Check answer
always @(*) begin
    count_A = (answer[0 * 8 +: 8] == guess_answer[0 * 8 +: 8]) + (answer[1 * 8 +: 8] == guess_answer[1 * 8 +: 8]) + (answer[2 * 8 +: 8] == guess_answer[2 * 8 +: 8]) + (answer[3 * 8 +: 8] == guess_answer[3 * 8 +: 8]);
    count_B = (answer[0 * 8 +: 8] == guess_answer[1 * 8 +: 8]) + (answer[0 * 8 +: 8] == guess_answer[2 * 8 +: 8]) + (answer[0 * 8 +: 8] == guess_answer[3 * 8 +: 8]) + 
              (answer[1 * 8 +: 8] == guess_answer[0 * 8 +: 8]) + (answer[1 * 8 +: 8] == guess_answer[2 * 8 +: 8]) + (answer[1 * 8 +: 8] == guess_answer[3 * 8 +: 8]) + 
              (answer[2 * 8 +: 8] == guess_answer[0 * 8 +: 8]) + (answer[2 * 8 +: 8] == guess_answer[1 * 8 +: 8]) + (answer[2 * 8 +: 8] == guess_answer[3 * 8 +: 8]) + 
              (answer[3 * 8 +: 8] == guess_answer[0 * 8 +: 8]) + (answer[3 * 8 +: 8] == guess_answer[1 * 8 +: 8]) + (answer[3 * 8 +: 8] == guess_answer[2 * 8 +: 8]);
end

assign answer_hit = (answer == guess_answer); 
assign set_error =  (answer[0 * 8 +: 8] == answer[1 * 8 +: 8]) | (answer[0 * 8 +: 8] == answer[2 * 8 +: 8]) | (answer[0 * 8 +: 8] == answer[3 * 8 +: 8]) | 
                    (answer[1 * 8 +: 8] == answer[0 * 8 +: 8]) | (answer[1 * 8 +: 8] == answer[2 * 8 +: 8]) | (answer[1 * 8 +: 8] == answer[3 * 8 +: 8]) | 
                    (answer[2 * 8 +: 8] == answer[0 * 8 +: 8]) | (answer[2 * 8 +: 8] == answer[1 * 8 +: 8]) | (answer[2 * 8 +: 8] == answer[3 * 8 +: 8]) | 
                    (answer[3 * 8 +: 8] == answer[0 * 8 +: 8]) | (answer[3 * 8 +: 8] == answer[1 * 8 +: 8]) | (answer[3 * 8 +: 8] == answer[2 * 8 +: 8]) | 
                    (answer[0 * 8 +: 8] == "X") | (answer[1 * 8 +: 8] == "X") | (answer[2 * 8 +: 8] == "X") | (answer[3 * 8 +: 8] == "X");
assign guess_error =  (guess_answer[0 * 8 +: 8] == guess_answer[1 * 8 +: 8]) | (guess_answer[0 * 8 +: 8] == guess_answer[2 * 8 +: 8]) | (guess_answer[0 * 8 +: 8] == guess_answer[3 * 8 +: 8]) | 
                      (guess_answer[1 * 8 +: 8] == guess_answer[0 * 8 +: 8]) | (guess_answer[1 * 8 +: 8] == guess_answer[2 * 8 +: 8]) | (guess_answer[1 * 8 +: 8] == guess_answer[3 * 8 +: 8]) | 
                      (guess_answer[2 * 8 +: 8] == guess_answer[0 * 8 +: 8]) | (guess_answer[2 * 8 +: 8] == guess_answer[1 * 8 +: 8]) | (guess_answer[2 * 8 +: 8] == guess_answer[3 * 8 +: 8]) | 
                      (guess_answer[3 * 8 +: 8] == guess_answer[0 * 8 +: 8]) | (guess_answer[3 * 8 +: 8] == guess_answer[1 * 8 +: 8]) | (guess_answer[3 * 8 +: 8] == guess_answer[2 * 8 +: 8]) |
                      (guess_answer[0 * 8 +: 8] == "X") | (guess_answer[1 * 8 +: 8] == "X") | (guess_answer[2 * 8 +: 8] == "X") | (guess_answer[3 * 8 +: 8] == "X");
debounce btn_db0(.clk(clk),.btn_input(usr_btn[0]),.btn_output(btn[0]));
debounce btn_db1(.clk(clk),.btn_input(usr_btn[1]),.btn_output(btn[1]));
debounce btn_db2(.clk(clk),.btn_input(usr_btn[2]),.btn_output(btn[2]));
debounce btn_db3(.clk(clk),.btn_input(usr_btn[3]),.btn_output(btn[3]));
always @(posedge clk) begin
    for(i = 0; i < 4; i = i + 1)begin
    if (~reset_n)
        reg_btn[i] <= 1;
    else
        reg_btn[i] <= btn[i];
    end
end
assign btn_pressed[0] = (btn[0] == 1 && reg_btn[0] == 0);
assign btn_pressed[1] = (btn[1] == 1 && reg_btn[1] == 0);
assign btn_pressed[2] = (btn[2] == 1 && reg_btn[2] == 0);
assign btn_pressed[3] = (btn[3] == 1 && reg_btn[3] == 0);

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

endmodule


module debounce(
input clk,
input btn_input,
output reg btn_output
);
reg [31:0] timer = 0;
reg pre;
always@(posedge clk)begin
    if(timer < 1000000)
        timer = timer + 1;
    else begin
        if(pre == btn_input)
            btn_output = btn_input;
        pre = btn_input;
        timer = 0;
    end
end
endmodule