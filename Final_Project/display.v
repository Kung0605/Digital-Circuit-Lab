`timescale 1ns / 1ps

module display(
  input  clk,
  input  reset_n,

  input  start,
  input  over,
  input  [4*4-1:0] tetris_score_bcd,
  input  [3:0] kind,
  input  [3:0] hold,
  input  [3:0] next,
  input  hold_locked,
  input  [4:0] pending_mask,
  output reg [4:0] tetris_x, tetris_y,

  // VGA specific I/O ports
  output VGA_HSYNC,
  output VGA_VSYNC,
  output [3:0] VGA_RED,
  output [3:0] VGA_GREEN,
  output [3:0] VGA_BLUE
);

  // ---------- SRAM PART ---------------
  localparam BG_W      = 320;
  localparam BG_H      = 240;
  localparam BLOCK_W   = 40;
  localparam BLOCK_H   = 40;
  localparam NUM_W     = 5;
  localparam NUM_H     = 9;
  localparam PIC_W     = 100;
  localparam START_PIC = 66;
  localparam END_PIC   = 60;

  localparam DATA_SIZE = BLOCK_W * BLOCK_H * 8 + NUM_W * NUM_H * 10 + 
                         PIC_W * START_PIC + PIC_W * END_PIC + 3;

  wire [16:0] bg_addr;
  wire [16:0] sram_addr;
  reg  [17:0] pixel_addr;           // Block pixel address
  reg  [17:0] bg_addr_reg;          // Background pixel address
  wire [11:0] data_in;
  wire [11:0] data_out;             // Block pixel
  wire [11:0] bg_out;               // Background pixel
  wire sram_we, sram_en;
  wire [8:0] pixel_x,    pixel_y,   // [0,320), [0,240)
             pixel_x_d,  pixel_y_d,
             pixel_x_dd, pixel_y_dd;

  assign data_in   = 12'h000;
  assign sram_we   = 0;
  assign sram_en   = 1;
  assign bg_addr   = bg_addr_reg;
  assign sram_addr = pixel_addr;


  sram #(.DATA_WIDTH(12), .ADDR_WIDTH(17), .RAM_SIZE(BG_W * BG_H), .FILE("backg.mem"))
  ram0 (.clk(clk), .we(sram_we), .en(sram_en), .addr(bg_addr), .data_i(data_in), .data_o(bg_out));

  sram #(.DATA_WIDTH(12), .ADDR_WIDTH(17), .RAM_SIZE(DATA_SIZE), .FILE("block.mem"))
  ram1 (.clk(clk), .we(sram_we), .en(sram_en), .addr(sram_addr), .data_i(data_in), .data_o(data_out));


  // Video frame buffer address generation unit (AGU) with scaling control.
  // Note that the width x height of the fish image is 64 x 32, when scaled-up on the screen, it becomes 128 x 64.
  // 'pos' specifies the right edge of the fish image.
  always @ (posedge clk) begin
    if (~reset_n)
      bg_addr_reg <= 0;
    else 
      bg_addr_reg <= pixel_y_dd * BG_W + pixel_x_dd;    // LOOK VGA PART
  end

  // ------------------------------------------------------
  reg [17:0] block_addr     [0:10];   // Address array for up to 7 block images. 
  reg [17:0] num_addr       [0:9];    // Address array for up to 10 number images. 0 ~ 9
  reg [17:0] pic_addr       [0:1];
  
  initial begin
    block_addr[0]  = BLOCK_W * BLOCK_H * 8 + NUM_W * NUM_H * 10 + 
                     PIC_W * START_PIC + PIC_W * END_PIC;

    block_addr[1]  = BLOCK_W * BLOCK_H * 0;
    block_addr[2]  = BLOCK_W * BLOCK_H * 1;
    block_addr[3]  = BLOCK_W * BLOCK_H * 2;
    block_addr[4]  = BLOCK_W * BLOCK_H * 3;
    block_addr[5]  = BLOCK_W * BLOCK_H * 4;
    block_addr[6]  = BLOCK_W * BLOCK_H * 5;
    block_addr[7]  = BLOCK_W * BLOCK_H * 6;
    block_addr[8]  = BLOCK_W * BLOCK_H * 7;
    block_addr[9]  = BLOCK_W * BLOCK_H * 8;

    block_addr[10] = BLOCK_W * BLOCK_H * 8 + NUM_W * NUM_H * 10 + 
                     PIC_W * START_PIC + PIC_W * END_PIC + 1;
  end

  initial begin
    num_addr[0] = BLOCK_W * BLOCK_H * 8 + NUM_W * NUM_H * 0;
    num_addr[1] = BLOCK_W * BLOCK_H * 8 + NUM_W * NUM_H * 1;
    num_addr[2] = BLOCK_W * BLOCK_H * 8 + NUM_W * NUM_H * 2;
    num_addr[3] = BLOCK_W * BLOCK_H * 8 + NUM_W * NUM_H * 3;
    num_addr[4] = BLOCK_W * BLOCK_H * 8 + NUM_W * NUM_H * 4;
    num_addr[5] = BLOCK_W * BLOCK_H * 8 + NUM_W * NUM_H * 5;
    num_addr[6] = BLOCK_W * BLOCK_H * 8 + NUM_W * NUM_H * 6;
    num_addr[7] = BLOCK_W * BLOCK_H * 8 + NUM_W * NUM_H * 7;
    num_addr[8] = BLOCK_W * BLOCK_H * 8 + NUM_W * NUM_H * 8;
    num_addr[9] = BLOCK_W * BLOCK_H * 8 + NUM_W * NUM_H * 9;

    pic_addr[0] = BLOCK_W * BLOCK_H * 8 + NUM_W * NUM_H * 10;
    pic_addr[1] = BLOCK_W * BLOCK_H * 8 + NUM_W * NUM_H * 10 + PIC_W * START_PIC;
  end

  wire [7:0] block_type[0:7];
  assign block_type[0] = 8'b0000_0000; // unuse
  assign block_type[1] = 8'b1111_0000;
  assign block_type[2] = 8'b1000_1110;
  assign block_type[3] = 8'b0010_1110;
  assign block_type[4] = 8'b0110_0110;
  assign block_type[5] = 8'b0110_1100;
  assign block_type[6] = 8'b0100_1110;
  assign block_type[7] = 8'b1100_0110;
  // 0000 1111 1000 0100 0110 0110 0100 1100
  // 0000 0000 1110 1110 0110 1100 1110 0110

  // ---------- VGA PART ---------------
  wire       visible;                  // when visible is 0, the VGA controller is sending synchronization signals to the display device.
  wire       p_tick;                   // when p_tick is 1,  we must update the RGB value based for the new coordinate (pixel_x, pixel_y)
  wire [9:0] pixel_x2,    pixel_y2;    // [0,640), [0,480)
  reg  [9:0] pixel_x2_d,  pixel_y2_d,
             pixel_x2_dd, pixel_y2_dd;

  vga_sync_reg vs0(
    .clk(clk), .reset(~reset_n), .oHS(VGA_HSYNC), .oVS(VGA_VSYNC),
    .visible(visible),  .p_tick(p_tick),
    .pixel_x(pixel_x2), .pixel_y(pixel_y2)
  );

  always @(posedge clk) begin
    pixel_x2_d  <= pixel_x2;
    pixel_y2_d  <= pixel_y2;

    pixel_x2_dd <= pixel_x2_d;
    pixel_y2_dd <= pixel_y2_d;
  end
             
  assign pixel_x    = pixel_x2    >> 1; // pixel_x2 from vga_sync_reg
  assign pixel_y    = pixel_y2    >> 1; // pixel_y2 from vga_sync_reg

  assign pixel_x_d  = pixel_x2_d  >> 1; // pixel_x2_d is last clk      pixel_x2;
  assign pixel_y_d  = pixel_y2_d  >> 1; // pixel_y2_d is last clk      pixel_y2;

  assign pixel_x_dd = pixel_x2_dd >> 1; // pixel_x2_dd is last last clk pixel_x2;
  assign pixel_y_dd = pixel_y2_dd >> 1; // pixel_y2_dd is last last clk pixel_y2;

  // ----- output ------
  // return the box addr of tetris
  always @(posedge clk) begin
    tetris_x <= (pixel_x2 - 220) / 20;
    tetris_y <= (pixel_y2 -  40) / 20;
  end

  // ----------- RGB & display part-------------
  reg  [11:0] rgb_reg;  // RGB value for the current pixel
  reg  [11:0] rgb_next; // RGB value for the next pixel

  assign {VGA_RED, VGA_GREEN, VGA_BLUE} = rgb_reg;

  always @(*) begin
    if (~visible)
      rgb_next = 12'h000; // Synchronization period, must set RGB values to zero.

    else if (data_out != 12'hfff) // if block emage has color -> output block, else background
      rgb_next = data_out;

    else
      rgb_next = bg_out;
  end

  always @(posedge clk) begin
    if (p_tick) rgb_reg <= rgb_next;
  end

  // ----------- init from input -------------
  wire [3:0]  score [0:3];
  assign score[3] = tetris_score_bcd[ 0+:4];
  assign score[2] = tetris_score_bcd[ 4+:4];
  assign score[1] = tetris_score_bcd[ 8+:4];
  assign score[0] = tetris_score_bcd[12+:4];

  // ---------- use pixel_x2_dd & pixel_y2_dd ---------------
  wire   tetris_box;
  wire   hold_box;
  wire   next_box;
  assign tetris_box     = (220 <= pixel_x2_dd) & (pixel_x2_dd < 420) & (40 <= pixel_y2_dd) & (pixel_y2_dd < 440);   // area for tetris board
  assign hold_box       = (450 <  pixel_x2_dd) & (490 > pixel_x2_dd) & (230 <= pixel_y2_dd) & (250 > pixel_y2_dd);  // area for hold
  assign next_box       = (450 <  pixel_x2_dd) & (490 > pixel_x2_dd) & (70  <= pixel_y2_dd) & (90  > pixel_y2_dd);  // area for next

  // area for the pic of start / end
  wire   start_region;
  wire   end_region;
  assign start_region   = (220 <= pixel_x2_dd) & (pixel_x2_dd < 420) & (174 <= pixel_y2_dd) & (pixel_y2_dd < 306);
  assign end_region     = (220 <= pixel_x2_dd) & (pixel_x2_dd < 420) & (180 <= pixel_y2_dd) & (pixel_y2_dd < 300);

  // ---------- use pixel_x_dd & pixel_y_dd ---------------
  // area for scoreboard
  wire score_box [0:3];

  assign score_box[0] = (223 <= pixel_x_dd) & (pixel_x_dd < 228) & (87 <= pixel_y_dd) & (pixel_y_dd < 96);
  assign score_box[1] = (231 <= pixel_x_dd) & (pixel_x_dd < 236) & (87 <= pixel_y_dd) & (pixel_y_dd < 96);
  assign score_box[2] = (238 <= pixel_x_dd) & (pixel_x_dd < 243) & (87 <= pixel_y_dd) & (pixel_y_dd < 96);
  assign score_box[3] = (245 <= pixel_x_dd) & (pixel_x_dd < 250) & (87 <= pixel_y_dd) & (pixel_y_dd < 96);

  // ----------------------------------------------------
  reg [4:0] block_x,      block_y;
  reg [3:0] block_next_x, block_next_y;
  reg [3:0] block_hold_x, block_hold_y;

  reg [1:0] mask_next_x,  mask_hold_x;
  reg       mask_next_y,  mask_hold_y;

  reg [9:0] start_x,        start_y;
  reg [9:0] end_x,          end_y;

  always @(posedge clk) begin
    block_x        <= (pixel_x2_d - 220) % 20;
    block_y        <= (pixel_y2_d -  40) % 20;

    block_next_x   <= (pixel_x2_d) % 10;
    block_next_y   <= (pixel_y2_d) % 10;

    block_hold_x   <= (pixel_x2_d - 450) % 10;
    block_hold_y   <= (pixel_y2_d) %10;

    mask_next_x    <= 3 - (pixel_x2_d - 450) / 10;
    mask_hold_x    <= 3 - (pixel_x2_d - 450) / 10;

    mask_next_y    <= ((pixel_y2_d) / 10 + 1) % 2;
    mask_hold_y    <= ((pixel_y2_d) / 10)     % 2;

    start_x        <= ((pixel_x2_d) - 220) >> 1;
    start_y        <= ((pixel_y2_d) - 174) >> 1;

    end_x          <= ((pixel_x2_d) - 220) >> 1;
    end_y          <= ((pixel_y2_d) - 180) >> 1;
  end

  // ----------------- pixel_addr ---------------------------------
  always @(posedge clk) begin
    if (~start) begin    // start = 0
      if (start_region)  pixel_addr <= pic_addr[0] + start_x + start_y * PIC_W;
      else               pixel_addr <= block_addr[10];
    end

    else if (over && end_region) pixel_addr <= pic_addr[1] + end_x + end_y * PIC_W;

    else if (tetris_box) begin 
      case (kind) // kind is input
        4'b0000: begin
          if (block_x == 0 || block_y == 0)  pixel_addr <= 25852;
          else                               pixel_addr <= block_addr[0];
        end
        4'b0001: pixel_addr <= block_addr[1] + (block_y >> 1) * BLOCK_W + (block_x >> 1);
        4'b0010: pixel_addr <= block_addr[2] + (block_y >> 1) * BLOCK_W + (block_x >> 1);
        4'b0011: pixel_addr <= block_addr[3] + (block_y >> 1) * BLOCK_W + (block_x >> 1);
        4'b0100: pixel_addr <= block_addr[4] + (block_y >> 1) * BLOCK_W + (block_x >> 1);
        4'b0101: pixel_addr <= block_addr[5] + (block_y >> 1) * BLOCK_W + (block_x >> 1);
        4'b0110: pixel_addr <= block_addr[6] + (block_y >> 1) * BLOCK_W + (block_x >> 1);
        4'b0111: pixel_addr <= block_addr[7] + (block_y >> 1) * BLOCK_W + (block_x >> 1);
        4'b1000: pixel_addr <= block_addr[8] + (block_y >> 1) * BLOCK_W + (block_x >> 1);
        4'b1001: pixel_addr <= block_addr[8] + (block_y >> 1) * BLOCK_W + (block_x >> 1);
      endcase
    end

    else if (score_box[0])  pixel_addr <= num_addr[score[0]] + (pixel_x_dd - 223) + (pixel_y_dd - 87) * NUM_W;
    else if (score_box[1])  pixel_addr <= num_addr[score[1]] + (pixel_x_dd - 231) + (pixel_y_dd - 87) * NUM_W;
    else if (score_box[2])  pixel_addr <= num_addr[score[2]] + (pixel_x_dd - 238) + (pixel_y_dd - 87) * NUM_W;
    else if (score_box[3])  pixel_addr <= num_addr[score[3]] + (pixel_x_dd - 245) + (pixel_y_dd - 87) * NUM_W;

    else if (next_box && block_type[next][mask_next_y * 4 + mask_next_x])  
      pixel_addr <= block_addr[next] + (block_next_y) * BLOCK_W + block_next_x;

    else if (hold_box && block_type[hold][mask_hold_y * 4 + mask_hold_x]) begin                        // hold, hold_locked are input
      if (~hold_locked)     pixel_addr <= block_addr[hold] + (block_hold_y) * BLOCK_W + block_hold_x;
      else                  pixel_addr <= block_addr[8]    + (block_hold_y) * BLOCK_W + block_hold_x;
    end

    // output background
    else                                               pixel_addr <= block_addr[0];
  end

endmodule
