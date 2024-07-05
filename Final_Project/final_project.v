`timescale 1ns / 1ps


module final_project (
  input  clk,
  input  reset_n,
  input  [3:0] usr_btn,
  input  [3:0] usr_sw,
  output VGA_HSYNC,
  output VGA_VSYNC,
  output [3:0] VGA_RED,
  output [3:0] VGA_GREEN,
  output [3:0] VGA_BLUE
);
  // General VGA control signals
  wire clk_25MHz;       // 25MHz clock for VGA control

  wire [4:0] tetris_x, tetris_y; // posision of current tetris
  wire [7:0] tetris_ctrl;        
  wire [7:0] tetris_state;
  wire [4*4-1:0] tetris_score_bcd;
  reg  [4*4-1:0] tetris_score;
  wire score_inc;
  wire [3:0] tetris_kind, tetris_hold, tetris_next;
  wire hold_locked, start, over;
  wire [4:0] pending_counter;

  // sequential logic
  always @(posedge clk) 
    tetris_score <= ((~(reset_n && start)) ? 0 : tetris_score + score_inc);

  wire [31:0] rng;
  wire [3:0] btn_pressed;
  clk_wiz_0 clk_wiz_0_0(
    .clk_25MHz(clk_25MHz),
    .clk_in1(clk)
  );

  display display0(
    .clk(clk_25MHz),
    .reset_n(reset_n),
    .start(start),
    .over(over),
    .tetris_score_bcd(tetris_score_bcd),
    .kind(tetris_kind),
    .hold(tetris_hold),
    .next(tetris_next),
    .hold_locked(hold_locked),
    .tetris_x(tetris_x),
    .tetris_y(tetris_y),
    .VGA_HSYNC(VGA_HSYNC),
    .VGA_VSYNC(VGA_VSYNC),
    .VGA_RED(VGA_RED),
    .VGA_GREEN(VGA_GREEN),
    .VGA_BLUE(VGA_BLUE)
  );

  block_control block_control0(
    .clk(clk_25MHz),
    .reset_n(reset_n), 
    .rng(rng),
    .x(tetris_x),
    .y(tetris_y),
    .ctrl(tetris_ctrl),
    .state(tetris_state),
    .score_bcd(tetris_score_bcd),
    .score_inc(score_inc),
    .kind(tetris_kind),
    .hold(tetris_hold),
    .next(tetris_next),
    .hold_locked(hold_locked),
    .pending_counter(pending_counter),
    .btn_pressed_i(btn_pressed)
  );
  

  random_number_generator random_number_generator0(
    .clk(clk_25MHz),
    .reset_n(reset_n),
    .rng(rng)
  );
    
  flow_control flow_control0(   
    .clk(clk_25MHz),
    .reset_n(reset_n),
    .rng_input(rng),
    .usr_btn(usr_btn),
    .usr_sw(usr_sw),
    .state_input(tetris_state),
    .score_input(tetris_score),
    .score_inc_input(score_inc),
    .control_output(tetris_ctrl),
    .start_output(start),
    .over_output(over),
    .btn_pressed_output(btn_pressed)
  );
endmodule
