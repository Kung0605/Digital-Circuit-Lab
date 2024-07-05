`define MAX_MD5 1
module Lab_9(
    input clk, 
    input reset_n,
    input [3 : 0] usr_btn,
    
    output LCD_RS,
    output LCD_RW,
    output LCD_E,
    output [3:0] LCD_D
);
    
    reg  [127:0] row_A = "Press BTN3      ";
    reg  [127:0] row_B = "to Start        ";
    reg [0:127] passwd_hash = 128'he8cd0953abdfde433dfec7faa70df7f6;
    localparam S_INIT = 0,
                       S_CRACKING = 1,
                       S_COMPLETE = 2,
                       S_SHOW = 3;
    reg [2 : 0] state, next_state;
    reg prev_btn_level;
    wire btn_pressed;
    wire cracked;
    LCD_module lcd0(.clk(clk), .reset(~reset_n), .row_A(row_A), .row_B(row_B),
                .LCD_E(LCD_E), .LCD_RS(LCD_RS), .LCD_RW(LCD_RW), .LCD_D(LCD_D));
    debounce btn_db(
      .clk(clk),
      .btn_input(usr_btn[3]),
      .btn_output(btn_level)
    );
    always @(posedge clk) begin
      if (~reset_n)
        prev_btn_level <= 2'b00;
      else
        prev_btn_level <= btn_level;
    end

    assign btn_pressed = (btn_level & ~prev_btn_level);
    always @(posedge clk) begin
        if (~reset_n) 
            state <= S_INIT;
        else 
            state <= next_state;
    end    
    always @(*) begin
        case (state)
            S_INIT : next_state = (btn_pressed ? S_CRACKING : S_INIT);
            S_CRACKING : next_state = (cracked ? S_COMPLETE : S_CRACKING);
            S_COMPLETE : next_state = S_SHOW;
            S_SHOW : next_state = (btn_pressed ? S_INIT : S_SHOW);
        endcase
    end
    (* mark_debug = "true"*) reg [7 : 0] counter [0 : 7];
    wire turn_finished;
    wire [0 : 7] carry;
    assign carry[0] = counter[0] == 9;
    assign carry[1] = counter[1] == 9;
    assign carry[2] = counter[2] == 9;
    assign carry[3] = counter[3] == 9;
    assign carry[4] = counter[4] == 9;
    assign carry[5] = counter[5] == 9;
    assign carry[6] = counter[6] == 9;
    assign carry[7] = counter[7] == 9;
    integer i;
    always@(posedge clk) begin
        if (~reset_n | state != S_CRACKING) begin
            for (i = 0; i < 8; i = i + 1)
                counter[i] <= 00000000;
        end
        else if (turn_finished) begin
            if  (&carry[1 : 7]) begin
                for (i = 1; i < 8; i = i + 1)
                    counter[i] <= 0;
                counter[0] <= counter[0] + 1;
            end
            else if (&carry[2 : 7]) begin
                for (i = 2; i < 8; i = i + 1) 
                    counter[i] <= 0;
                counter[1] <= counter[1] + 1;
            end
            else if (&carry[3 : 7]) begin
                for (i = 3; i < 8; i = i + 1)
                    counter[i] <= 0;
                counter[2] <= counter[2] + 1;
            end
            else if (&carry[4 : 7]) begin
                for (i = 4; i < 8; i = i + 1)
                    counter[i] <= 0;
                counter[3] <= counter[3] + 1;
            end
            else if (&carry[5 : 7]) begin
                for (i = 5; i < 8; i = i + 1)
                    counter[i] <= 0;
                counter[4] <= counter[4] + 1;
            end
            else if (&carry[6 : 7]) begin
                for (i = 6; i < 8; i = i + 1) 
                    counter[i] <= 0;
                counter[5] <= counter[5] + 1;
            end
            else if (carry[7]) begin
                counter[7] <= 0;
                counter[6] <= counter[6] + 1;
            end
            else begin
                counter[7] <= counter[7] + 1;
            end
        end
    end
    (*mark_debug = "true"*)wire [63 : 0] ascii_counter;
    genvar jdx;
    generate
        for (jdx = 0; jdx < 8; jdx = jdx + 1) begin
            assign ascii_counter[jdx * 8 +: 8] = (counter[7 - jdx] + 48);
        end
    endgenerate
    wire [0 : 127] result [0 : `MAX_MD5 - 1];
    wire [0 : `MAX_MD5 - 1] finish;
    wire [0 : `MAX_MD5 - 1] correct;
    reg clear;
    genvar j;
    generate
        for (j = 0; j < `MAX_MD5; j = j + 1) begin : md5_inst
            md5_cracker m(
                .clk(clk),
                .reset_n(~btn_pressed),
                .clear(clear),
                .pwd_in({ascii_counter}),
                .result(result[j]),
                .finish(finish[j]),
                .correct(correct[j])
            );
        end
    endgenerate
    always @(posedge clk) begin
        clear <= |finish[0 : `MAX_MD5 - 1];
    end
    assign cracked = |correct[0 : `MAX_MD5 - 1];
    assign turn_finished = clear;
    reg [63 : 0] answer;
    (*mark_debug = "true"*) reg [31 : 0] time_taken;
    always @(posedge clk) begin
        if (~reset_n)
            time_taken <= 0;
        else if (state == S_SHOW)
            time_taken <= time_taken;
        else 
            time_taken <= time_taken + 1;
    end
    reg [63 : 0]tmp_crack;
    always @(*) begin
        for ( i = 0; i < 8; i = i + 1) 
            tmp_crack[i * 8 +: 8] = ascii_counter + "0";
    end
    always @(*) begin
        case(state)
             S_INIT : begin
                row_A <= "Press BTN3      ";
                row_B <= "To start        ";
             end
             S_CRACKING : begin
                row_A <= "Cracking        ";
                row_B <= {ascii_counter, "        "};
             end
             S_COMPLETE : begin
                row_A <= "                ";
                row_B <= "                ";
             end
             S_SHOW : begin
                row_A <= {"Passwd: ", answer};
                row_B <= {"Time:  ", time_char(time_taken)};
             end
        endcase
    end
    always @(posedge clk) begin
        if (~reset_n) 
            answer <= 0;
        else if (|correct[0 : `MAX_MD5 - 1])
            answer <= ascii_counter;
        else 
            answer <= answer;
    end
    function [63 : 0] time_char(input[31 : 0] t);
        for (i = 0; i < 8; i = i + 1) begin
            time_char[i * 8 +: 8] = (t[i * 4 +: 4] > 9 ? "A" + t[i * 4 +: 4] - 10 : "0" + t[i * 4 +: 4]);
        end
    endfunction
endmodule
