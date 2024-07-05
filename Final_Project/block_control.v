`timescale 1ns / 1ps
`define BCD_ADD(in, inc) \
    ((in) + (inc) + ((inc) && (in) >= 9 ? 6 : 0))

module block_control (
  input clk,
  input reset_n,
  input [31:0] rng, // random number generator

  input [4:0] x, y, // tetris position
  input [7:0] ctrl, // tetris control

  output reg [7:0] state,     // tetris state
  output reg [4*4-1:0] score_bcd,  // tetris score
  output score_inc, // tetris score increment
  output reg [3:0] kind,// tetris kind
  output reg [3:0] hold,// tetris hold
  output reg [3:0] next,// tetris next
  output reg hold_locked,// tetris hold locked
  output reg [4:0] pending_counter, 
  input [3:0] btn_pressed_i // button pressed
);
  genvar gi;
  wire [7:0] read_addr;
  wire outside,// outside of the screen
       boutside,
       valid,// valid position
       pvalid,// preview valid position
       do_clear;
  wire [1:0] next_rotate_idx,
             next_rotate_rev_idx;
  wire [4:0] left_x_blockindex,
             right_x_blockindex,
             down_y_blockindex;
  wire [2:0] hold_kind;
  wire [219:0] placed_block,
               gen_block,
               hold_block,
               rotate_block,
               rotate_rev_block,
               left_block,
               right_block,
               down_block,
               preview_down_block;
  reg [7:0] next_state;
  localparam  NONE       = 0, // no control
              INIT       = 1, // initialize
              GEN        = 2, // generate next tetris
              WAIT       = 3, // wait for control
              LEFT       = 4, // move left
              RIGHT      = 5, // move right
              DOWN       = 6, // move down
              DROP       = 7, // drop
              HOLD       = 8, // hold
              ROTATE     = 9, // rotate
              ROTATE_REV = 10,// rotate reverse
              PCHECK     = 12,// preview check
              DCHECK     = 13,// down check
              MCHECK     = 14,// move check
              HCHECK     = 15,// hold check
              CPREP      = 16,// clear prepare 
              CLEAR      = 17,// clear 
              BPLACE     = 18,
              END        = 19;
  // registers
  reg [3:0] curr_kind  = 0, // tetris kind
            check_kind = 0; // tetris kind to be checked
  reg [4:0] curr_x_blockindex  = 0,
            curr_y_blockindex  = 0,
            check_x_blockindex = 0,
            check_y_blockindex = 0;
  reg [1:0] curr_rotate_idx  = 0,
            check_rotate_idx = 0;
  reg [219:0] curr_block  = 0,
              check_block = 0,
              preview_block = 0;
  reg [199:0] placed_kind [3:0],// placed tetris kind
              test_block = 0,
              clear_block = 0,
              pending_block = 0;
  initial begin
    placed_kind[3] = 200'b0;
    placed_kind[2] = 200'b0;
    placed_kind[1] = 200'b0;
    placed_kind[0] = 200'b0;
  end
  reg [4:0] clear_counter   = 0;
  reg curr_block_updated = 0;
  reg [3:0] block[1:7][0:3][0:3];
  reg [4:0] min_x_blockindex[1:7][0:3];
  reg [4:0] max_x_blockindex[1:7][0:3];
  reg [4:0] max_y_blockindex[1:7][0:3];
  integer idx;
  assign read_addr = (19 - y) * 10 + (9 - x);// 0 ~ 219
  assign placed_block = {20'b0, placed_kind[3] | placed_kind[2] | placed_kind[1] | placed_kind[0]};
  assign outside = |curr_block[219 : 200];// outside of the screen
  assign boutside = |(placed_block >> 10 * (20 - pending_counter));// outside of the screen
  // vallid: not outside and not overlap
  assign valid = min_x_blockindex[check_kind][check_rotate_idx] <= check_x_blockindex &&
                 check_x_blockindex <= max_x_blockindex[check_kind][check_rotate_idx] &&
                 check_y_blockindex <= max_y_blockindex[check_kind][check_rotate_idx] &&
                 !(|(check_block & placed_block));
  // preview valid: not outside and not overlap                
  assign pvalid = !(|preview_block[9:0]) &&
                  !(|(preview_down_block & placed_block));
  // following varaibles are used for tetris control                  
  assign next_rotate_idx = curr_rotate_idx + 1;
  assign next_rotate_rev_idx = curr_rotate_idx - 1;
  assign left_x_blockindex = curr_x_blockindex - 1;
  assign right_x_blockindex = curr_x_blockindex + 1;
  assign down_y_blockindex = curr_y_blockindex + 1;
  assign hold_kind = (hold != 0 ? hold : next[0]);
  assign left_block = curr_block << 1;
  assign right_block = curr_block >> 1;
  assign down_block = curr_block >> 10;
  assign preview_down_block = preview_block >> 10;
  assign do_clear = &test_block[9:0];
  // state transition logic --------------------------------------
  always @(*) begin
    next_state = INIT;
    if (reset_n) case (state)
      INIT:
        next_state = (ctrl == NONE ? INIT : GEN);
      GEN:
        next_state = WAIT;
      WAIT:
        next_state = (ctrl <= WAIT ? WAIT : ctrl);
      HOLD:
        next_state = (hold_locked ? WAIT : HCHECK);
      LEFT, RIGHT, ROTATE, ROTATE_REV:
        next_state = MCHECK;
      DOWN:
        next_state = DCHECK;
      DROP:
        next_state = PCHECK;
      PCHECK: 
        next_state = valid ? DROP : outside ? END : CPREP;
      DCHECK: 
        next_state = valid ? DOWN : outside ? END : CPREP;
      MCHECK:
        next_state = WAIT;
      HCHECK:
        next_state = (hold ? WAIT : GEN);
      CPREP:
        next_state = CLEAR;
      CLEAR: 
        next_state = do_clear ? CPREP : clear_counter == 19 ? BPLACE : CLEAR;
      BPLACE:
        next_state = (boutside ? END : GEN);
      END:
        next_state = (ctrl ? INIT : END);
    endcase
  end
  // state register
  always @(posedge clk) begin 
    if (~reset_n)
      state <= INIT;
    else 
      state <= next_state;
  end

  reg [0:2] i;
  always @(posedge clk) begin
    if (state == GEN || state == PCHECK || state == DCHECK || state == MCHECK || state == HCHECK)
      curr_block_updated <= 1;
    else
      curr_block_updated <= 0;
  end
  always @(posedge clk) begin
    if (state == INIT)
      preview_block <= 0;
    else if (curr_block_updated)
      preview_block <= curr_block;
    else if (pvalid)
      preview_block <= preview_down_block;
    else 
      preview_block <= preview_block;
  end
  localparam MOVE_DOWN = 0,
             MOVE_ROTATE = 1,
             MOVE_OTHER = 2;
  reg [2:0] lines_cleared = 0;
  reg [7:0] score_pending = 0;
  reg [4:0] score_carry = 0;
  assign score_inc = score_carry[0];
  always @(posedge clk) begin
    score_carry[0] <= 0;
    if (~reset_n || state == INIT) begin
      lines_cleared <= 0;
      score_pending <= 0;
    end 
    else if (state == CLEAR && do_clear) begin
      lines_cleared <= lines_cleared + 1;
    end
    else if (state == BPLACE) begin
      lines_cleared <= 0;
      if (lines_cleared != 0) begin 
        if (lines_cleared == 1)
          score_pending <= score_pending + 1;
        else if (lines_cleared == 2)
          score_pending <= score_pending + 2;
        else if (lines_cleared == 3)
          score_pending <= score_pending + 4;
        else if (lines_cleared == 4)
          score_pending <= score_pending + 8;
        else
          score_pending <= score_pending;
      end
    end
    else if (score_pending != 0) begin
      score_pending <= score_pending - 1;
      score_carry[0] <= 1;
    end
  end
  assign gen_block = {3'b000, block[next][0][0], 3'b000,
                     3'b000, block[next][1][0], 3'b000,
                     3'b000, block[next][2][0], 3'b000,
                     3'b000, block[next][3][0], 3'b000,
                     180'b0};
  assign hold_block = {3'b000, block[hold_kind][0][0], 3'b000,
                      3'b000, block[hold_kind][1][0], 3'b000,
                      3'b000, block[hold_kind][2][0], 3'b000,
                      3'b000, block[hold_kind][3][0], 3'b000,
                      180'b0};
  assign rotate_block = {block[curr_kind][0][next_rotate_idx], 6'b000,
                        block[curr_kind][1][next_rotate_idx], 6'b000,
                        block[curr_kind][2][next_rotate_idx], 6'b000,
                        block[curr_kind][3][next_rotate_idx], 6'b000,
                        180'b0} >> (curr_x_blockindex - 2) >> (10 * curr_y_blockindex);
  assign rotate_rev_block = {block[curr_kind][0][next_rotate_rev_idx], 6'b000,
                            block[curr_kind][1][next_rotate_rev_idx], 6'b000,
                            block[curr_kind][2][next_rotate_rev_idx], 6'b000,
                            block[curr_kind][3][next_rotate_rev_idx], 6'b000,
                            180'b0} >> (curr_x_blockindex - 2) >> (10 * curr_y_blockindex);
  integer j;
  always @(posedge clk) begin 
    for(j = 0; j < 4; j = j + 1) begin 
      if (~reset_n || state == INIT)
        score_bcd[j*4+:4] <= 0;
      else
        { score_carry[j+1], score_bcd[j*4+:4] } <= `BCD_ADD(score_bcd[j*4+:4], score_carry[j]);
    end
  end
  // next tetris
  always @(posedge clk) begin
    if (~reset_n || state == INIT)
      next <= rng[0+:3];
    else if (state == GEN) 
      next <= rng[0+:3];
    else if (next == 0)
      next <= rng[0+:3];
    else 
      next <= next;
  end
  initial begin
    block[1][0][0] = 4'b0000; block[1][0][1] = 4'b0010; block[1][0][2] = 4'b0000; block[1][0][3] = 4'b0100;
    block[1][1][0] = 4'b1111; block[1][1][1] = 4'b0010; block[1][1][2] = 4'b0000; block[1][1][3] = 4'b0100;
    block[1][2][0] = 4'b0000; block[1][2][1] = 4'b0010; block[1][2][2] = 4'b1111; block[1][2][3] = 4'b0100;
    block[1][3][0] = 4'b0000; block[1][3][1] = 4'b0010; block[1][3][2] = 4'b0000; block[1][3][3] = 4'b0100;
    block[2][0][0] = 4'b1000; block[2][0][1] = 4'b0110; block[2][0][2] = 4'b0000; block[2][0][3] = 4'b0100;
    block[2][1][0] = 4'b1110; block[2][1][1] = 4'b0100; block[2][1][2] = 4'b1110; block[2][1][3] = 4'b0100;
    block[2][2][0] = 4'b0000; block[2][2][1] = 4'b0100; block[2][2][2] = 4'b0010; block[2][2][3] = 4'b1100;
    block[2][3][0] = 4'b0000; block[2][3][1] = 4'b0000; block[2][3][2] = 4'b0000; block[2][3][3] = 4'b0000;
    block[3][0][0] = 4'b0010; block[3][0][1] = 4'b0100; block[3][0][2] = 4'b0000; block[3][0][3] = 4'b1100;
    block[3][1][0] = 4'b1110; block[3][1][1] = 4'b0100; block[3][1][2] = 4'b1110; block[3][1][3] = 4'b0100;
    block[3][2][0] = 4'b0000; block[3][2][1] = 4'b0110; block[3][2][2] = 4'b1000; block[3][2][3] = 4'b0100;
    block[3][3][0] = 4'b0000; block[3][3][1] = 4'b0000; block[3][3][2] = 4'b0000; block[3][3][3] = 4'b0000;
    block[4][0][0] = 4'b0110; block[4][0][1] = 4'b0110; block[4][0][2] = 4'b0110; block[4][0][3] = 4'b0110;
    block[4][1][0] = 4'b0110; block[4][1][1] = 4'b0110; block[4][1][2] = 4'b0110; block[4][1][3] = 4'b0110;
    block[4][2][0] = 4'b0000; block[4][2][1] = 4'b0000; block[4][2][2] = 4'b0000; block[4][2][3] = 4'b0000;
    block[4][3][0] = 4'b0000; block[4][3][1] = 4'b0000; block[4][3][2] = 4'b0000; block[4][3][3] = 4'b0000;
    block[5][0][0] = 4'b0110; block[5][0][1] = 4'b0100; block[5][0][2] = 4'b0000; block[5][0][3] = 4'b1000;
    block[5][1][0] = 4'b1100; block[5][1][1] = 4'b0110; block[5][1][2] = 4'b0110; block[5][1][3] = 4'b1100;
    block[5][2][0] = 4'b0000; block[5][2][1] = 4'b0010; block[5][2][2] = 4'b1100; block[5][2][3] = 4'b0100;
    block[5][3][0] = 4'b0000; block[5][3][1] = 4'b0000; block[5][3][2] = 4'b0000; block[5][3][3] = 4'b0000;
    block[6][0][0] = 4'b0100; block[6][0][1] = 4'b0100; block[6][0][2] = 4'b0000; block[6][0][3] = 4'b0100;
    block[6][1][0] = 4'b1110; block[6][1][1] = 4'b0110; block[6][1][2] = 4'b1110; block[6][1][3] = 4'b1100;
    block[6][2][0] = 4'b0000; block[6][2][1] = 4'b0100; block[6][2][2] = 4'b0100; block[6][2][3] = 4'b0100;
    block[6][3][0] = 4'b0000; block[6][3][1] = 4'b0000; block[6][3][2] = 4'b0000; block[6][3][3] = 4'b0000;
    block[7][0][0] = 4'b1100; block[7][0][1] = 4'b0010; block[7][0][2] = 4'b0000; block[7][0][3] = 4'b0100;
    block[7][1][0] = 4'b0110; block[7][1][1] = 4'b0110; block[7][1][2] = 4'b1100; block[7][1][3] = 4'b1100;
    block[7][2][0] = 4'b0000; block[7][2][1] = 4'b0100; block[7][2][2] = 4'b0110; block[7][2][3] = 4'b1000;
    block[7][3][0] = 4'b0000; block[7][3][1] = 4'b0000; block[7][3][2] = 4'b0000; block[7][3][0] = 4'b0000;
  end
  initial begin
    // Initialize min_x_blockindex
    min_x_blockindex[1][0] = 2; min_x_blockindex[1][1] = 0; min_x_blockindex[1][2] = 2; min_x_blockindex[1][3] = 1;
    min_x_blockindex[2][0] = 2; min_x_blockindex[2][1] = 1; min_x_blockindex[2][2] = 2; min_x_blockindex[2][3] = 2;
    min_x_blockindex[3][0] = 2; min_x_blockindex[3][1] = 1; min_x_blockindex[3][2] = 2; min_x_blockindex[3][3] = 2;
    min_x_blockindex[4][0] = 1; min_x_blockindex[4][1] = 1; min_x_blockindex[4][2] = 1; min_x_blockindex[4][3] = 1;
    min_x_blockindex[5][0] = 2; min_x_blockindex[5][1] = 1; min_x_blockindex[5][2] = 2; min_x_blockindex[5][3] = 2;
    min_x_blockindex[6][0] = 2; min_x_blockindex[6][1] = 1; min_x_blockindex[6][2] = 2; min_x_blockindex[6][3] = 2;
    min_x_blockindex[7][0] = 2; min_x_blockindex[7][1] = 1; min_x_blockindex[7][2] = 2; min_x_blockindex[7][3] = 2;
  end
  initial begin
    // Initialize max_x_blockindex
    max_x_blockindex[1][0] = 8; max_x_blockindex[1][1] = 9; max_x_blockindex[1][2] = 8; max_x_blockindex[1][3] = 10;
    max_x_blockindex[2][0] = 9; max_x_blockindex[2][1] = 9; max_x_blockindex[2][2] = 9; max_x_blockindex[2][3] = 10;
    max_x_blockindex[3][0] = 9; max_x_blockindex[3][1] = 9; max_x_blockindex[3][2] = 9; max_x_blockindex[3][3] = 10;
    max_x_blockindex[4][0] = 9; max_x_blockindex[4][1] = 9; max_x_blockindex[4][2] = 9; max_x_blockindex[4][3] = 9;
    max_x_blockindex[5][0] = 9; max_x_blockindex[5][1] = 9; max_x_blockindex[5][2] = 9; max_x_blockindex[5][3] = 10;
    max_x_blockindex[6][0] = 9; max_x_blockindex[6][1] = 9; max_x_blockindex[6][2] = 9; max_x_blockindex[6][3] = 10;
    max_x_blockindex[7][0] = 9; max_x_blockindex[7][1] = 9; max_x_blockindex[7][2] = 9; max_x_blockindex[7][3] = 10;
  end
  initial begin
    // Initialize max_y_blockindex
    max_y_blockindex[1][0] = 20; max_y_blockindex[1][1] = 18; max_y_blockindex[1][2] = 19; max_y_blockindex[1][3] = 18;
    max_y_blockindex[2][0] = 20; max_y_blockindex[2][1] = 19; max_y_blockindex[2][2] = 19; max_y_blockindex[2][3] = 19;
    max_y_blockindex[3][0] = 20; max_y_blockindex[3][1] = 19; max_y_blockindex[3][2] = 19; max_y_blockindex[3][3] = 19;
    max_y_blockindex[4][0] = 20; max_y_blockindex[4][1] = 20; max_y_blockindex[4][2] = 20; max_y_blockindex[4][3] = 20;
    max_y_blockindex[5][0] = 20; max_y_blockindex[5][1] = 19; max_y_blockindex[5][2] = 19; max_y_blockindex[5][3] = 19;
    max_y_blockindex[6][0] = 20; max_y_blockindex[6][1] = 19; max_y_blockindex[6][2] = 19; max_y_blockindex[6][3] = 19;
    max_y_blockindex[7][0] = 20; max_y_blockindex[7][1] = 19; max_y_blockindex[7][2] = 19; max_y_blockindex[7][3] = 19;
  end
  always @(posedge clk) begin
    // initialize
    if (~reset_n || state == INIT) begin
      hold <= 0;
      curr_kind <= 0;
      curr_block <= 0;
      for (idx = 0; idx < 4; idx = idx + 1)
        placed_kind[idx] <= 0;
      pending_block <= 0;
      pending_counter <= 0;
      hold_locked <= 0;
    end else begin
      case (state)
        GEN: begin
          curr_kind <= next;
          curr_block <= gen_block;
          curr_x_blockindex <= 5;
          curr_y_blockindex <= 0;
          curr_rotate_idx <= 0;
        end
        HOLD: begin
          check_kind <= hold_kind;
          check_block <= hold_block;
          check_x_blockindex <= 5;
          check_y_blockindex <= 0;
          check_rotate_idx <= 0;
          hold_locked <= 1;
        end
        ROTATE: begin
          check_kind <= curr_kind;
          check_block <= rotate_block;
          check_x_blockindex <= curr_x_blockindex;
          check_y_blockindex <= curr_y_blockindex;
          check_rotate_idx <= next_rotate_idx;
        end
        ROTATE_REV: begin
          check_kind <= curr_kind;
          check_block <= rotate_rev_block;
          check_x_blockindex <= curr_x_blockindex;
          check_y_blockindex <= curr_y_blockindex;
          check_rotate_idx <= next_rotate_rev_idx;
        end
        LEFT: begin
          check_kind <= curr_kind;
          check_block <= left_block;
          check_x_blockindex <= left_x_blockindex;
          check_y_blockindex <= curr_y_blockindex;
          check_rotate_idx <= curr_rotate_idx;
        end
        RIGHT: begin
          check_kind <= curr_kind;
          check_block <= right_block;
          check_x_blockindex <= right_x_blockindex;
          check_y_blockindex <= curr_y_blockindex;
          check_rotate_idx <= curr_rotate_idx;
        end
        DOWN, DROP: begin
          check_kind <= curr_kind;
          check_block <= down_block;
          check_x_blockindex <= curr_x_blockindex;
          check_y_blockindex <= down_y_blockindex;
          check_rotate_idx <= curr_rotate_idx;
        end
        PCHECK, DCHECK, MCHECK, HCHECK: begin
          if (valid) begin
            curr_kind <= check_kind;
            curr_block <= check_block;
            curr_x_blockindex <= check_x_blockindex;
            curr_y_blockindex <= check_y_blockindex;
            curr_rotate_idx <= check_rotate_idx;
            if (state == HCHECK) 
              hold <= curr_kind;
          end
          else if ((state == PCHECK || state == DCHECK)) begin
            curr_block <= 0;
            placed_kind[3] <= placed_kind[3] | (curr_block[199:0] & {200{curr_kind[3]}});
            placed_kind[2] <= placed_kind[2] | (curr_block[199:0] & {200{curr_kind[2]}});
            placed_kind[1] <= placed_kind[1] | (curr_block[199:0] & {200{curr_kind[1]}});
            placed_kind[0] <= placed_kind[0] | (curr_block[199:0] & {200{curr_kind[0]}});
          end
        end
        CPREP: begin
          test_block <= placed_block;
          clear_block <= {200{1'b1}};
          clear_counter <= 0;
          hold_locked <= 0;
        end
        CLEAR: begin
          test_block <= test_block >> 10;
          clear_block <= clear_block << 10;
          clear_counter <= clear_counter + 1;
          if (do_clear) begin
            placed_kind[3] <= (placed_kind[3] & ~clear_block) | ((placed_kind[3] >> 10) & clear_block);
            placed_kind[2] <= (placed_kind[2] & ~clear_block) | ((placed_kind[2] >> 10) & clear_block);
            placed_kind[1] <= (placed_kind[1] & ~clear_block) | ((placed_kind[1] >> 10) & clear_block);
            placed_kind[0] <= (placed_kind[0] & ~clear_block) | ((placed_kind[0] >> 10) & clear_block);
          end
        end
        BPLACE: begin
          placed_kind[3] <= (placed_kind[3] << (10 * pending_counter)) | pending_block;
          placed_kind[2] <= (placed_kind[2] << (10 * pending_counter));
          placed_kind[1] <= (placed_kind[1] << (10 * pending_counter));
          placed_kind[0] <= (placed_kind[0] << (10 * pending_counter));
          pending_block <= 0;
          pending_counter <= 0;
        end
      endcase
    end
  end
  always @(posedge clk) begin 
    if (curr_block[read_addr])
      kind <= curr_kind;
    else if (preview_block[read_addr])
      kind <= 9;
    else begin
      kind <= {
        placed_kind[3][read_addr],
        placed_kind[2][read_addr],
        placed_kind[1][read_addr],
        placed_kind[0][read_addr]
      };
    end
  end
endmodule