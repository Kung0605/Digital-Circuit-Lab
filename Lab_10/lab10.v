`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of Computer Science, National Chiao Tung University
// Engineer: Chun-Jen Tsai 
// 
// Create Date: 2018/12/11 16:04:41
// Design Name: 
// Module Name: lab10
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: A circuit that show the animation of a fish swimming in a seabed
//              scene on a screen through the VGA interface of the Arty I/O card.
// 
// Dependencies: vga_sync, clk_divider, sram 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module lab10(
    input  clk,
    input  reset_n,
    input  [3:0] usr_btn,
    output [3:0] usr_led,
    
    // VGA specific I/O ports
    output VGA_HSYNC,
    output VGA_VSYNC,
    output [3:0] VGA_RED,
    output [3:0] VGA_GREEN,
    output [3:0] VGA_BLUE
    );

// Declare system variables
reg  [31:0] fish1_clock;
reg  [31:0] fish2_clock;
reg  [31:0] fish3_clock;
wire [9:0]  pos1;
wire [9:0]  pos2;
wire [9:0]  pos3;
wire        fish1_region;
wire        fish2_region;
wire        fish3_region;

// declare SRAM control signals
wire [16:0] sram_addr;
wire [16:0] sram_addr_transparent;
wire [16:0] sram2_addr1;
wire [16:0] sram2_addr2;
wire [11:0] data_in;
wire [11:0] data_in_transparent;
wire [11:0] data_out;
wire [11:0] data_out_transparent;
wire [11:0] data_out_fish2;
wire [11:0] data_out_fish3;
wire        sram_we, sram_en;

wire [2:0]  btn_level, btn_pressed;
reg  [2:0]  prev_btn_level;
// General VGA control signals
wire vga_clk;         // 50MHz clock for VGA control
wire video_on;        // when video_on is 0, the VGA controller is sending
                      // synchronization signals to the display device.
  
wire pixel_tick;      // when pixel tick is 1, we must update the RGB value
                      // based for the new coordinate (pixel_x, pixel_y)
  
wire [9:0] pixel_x;   // x coordinate of the next pixel (between 0 ~ 639) 
wire [9:0] pixel_y;   // y coordinate of the next pixel (between 0 ~ 479)
  
reg  [11:0] rgb_reg;  // RGB value for the current pixel
reg  [11:0] rgb_next; // RGB value for the next pixel
  
// Application-specific VGA signals
reg  [17:0] pixel_addr;
reg  [17:0] pixel_fish2_addr;
reg  [17:0] pixel_fish3_addr;
reg  [17:0] pixel_addr_transparent;

// Declare the video buffer size
localparam VBUF_W = 320; // video buffer width
localparam VBUF_H = 240; // video buffer height

// Set parameters for the fish images
localparam FISH_VPOS1  = 80; // Vertical location of the fish in the sea image.
wire [10:0]FISH_VPOS2;
wire [10:0]FISH_VPOS3;
localparam FISH_W      = 64; // Width of the fish.
localparam FISH_H1     = 32; // Height of the fish.
localparam FISH_H2     = 44;
localparam FISH_H3     = 44;

reg [17:0] fish1_addr [0:8];   // Address array for up to 8 fish images.
reg [17:0] fish2_addr [0:8];
reg [17:0] fish3_addr [0:8];

reg [2:0]  speed;
reg        reverse;
// Initializes the fish images starting addresses.
// Note: System Verilog has an easier way to initialize an array,
//       but we are using Verilog 2001 :(
initial begin
  fish1_addr[0] = VBUF_W*VBUF_H;
  fish1_addr[1] = VBUF_W*VBUF_H + FISH_W*FISH_H1;
  fish1_addr[2] = VBUF_W*VBUF_H + FISH_W*FISH_H1*2;
  fish1_addr[3] = VBUF_W*VBUF_H + FISH_W*FISH_H1*3;
  fish1_addr[4] = VBUF_W*VBUF_H + FISH_W*FISH_H1*4;
  fish1_addr[5] = VBUF_W*VBUF_H + FISH_W*FISH_H1*5;
  fish1_addr[6] = VBUF_W*VBUF_H + FISH_W*FISH_H1*6;
  fish1_addr[7] = VBUF_W*VBUF_H + FISH_W*FISH_H1*7;

  fish2_addr[0] = 0;
  fish2_addr[1] = FISH_W*FISH_H2;
  fish2_addr[2] = FISH_W*FISH_H2*2;
  fish2_addr[3] = FISH_W*FISH_H2*3;
  fish2_addr[4] = FISH_W*FISH_H2*4;
  fish2_addr[5] = FISH_W*FISH_H2*5;
  fish2_addr[6] = FISH_W*FISH_H2*6;
  fish2_addr[7] = FISH_W*FISH_H2*7;

  fish3_addr[0] = 0;
  fish3_addr[1] = FISH_W*FISH_H2;
  fish3_addr[2] = FISH_W*FISH_H2*2;
  fish3_addr[3] = FISH_W*FISH_H2*3;
  fish3_addr[4] = FISH_W*FISH_H2*4;
  fish3_addr[5] = FISH_W*FISH_H2*5;
  fish3_addr[6] = FISH_W*FISH_H2*6;
  fish3_addr[7] = FISH_W*FISH_H2*7;
end

// Instiantiate the VGA sync signal generator
vga_sync vs0(
  .clk(vga_clk), .reset(~reset_n), .oHS(VGA_HSYNC), .oVS(VGA_VSYNC),
  .visible(video_on), .p_tick(pixel_tick),
  .pixel_x(pixel_x), .pixel_y(pixel_y)
);

clk_divider#(2) clk_divider0(
  .clk(clk),
  .reset(~reset_n),
  .clk_out(vga_clk)
);

debounce btn_db0(
  .clk(clk),
  .btn_input(usr_btn[0]),
  .btn_output(btn_level[0])
);

debounce btn_db1(
  .clk(clk),
  .btn_input(usr_btn[1]),
  .btn_output(btn_level[1])
);

debounce btn_db2(
  .clk(clk),
  .btn_input(usr_btn[2]),
  .btn_output(btn_level[2])
);
always @(posedge clk) begin
  if (~reset_n)
    prev_btn_level <= 2'b00;
  else
    prev_btn_level <= btn_level;
end

assign btn_pressed = (btn_level & ~prev_btn_level);
// ------------------------------------------------------------------------
// The following code describes an initialized SRAM memory block that
// stores a 320x240 12-bit seabed image, plus two 64x32 fish images.
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(VBUF_W * VBUF_H + FISH_W * FISH_H1 * 8))
  ram0 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr1(sram_addr), .addr2(sram_addr_transparent),
          .data_i1(data_in), .data_i2(data_in_transparent),
          .data_o1(data_out), .data_o2(data_out_transparent));
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(FISH_W * FISH_H2 * 8), .FILE("images2.mem"))
  ram1 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr1(sram2_addr1), .addr2(sram2_addr2),
          .data_i1(data_in), .data_i2(data_in),
          .data_o1(data_out_fish2), .data_o2(data_out_fish3));

assign sram_we = usr_btn[3]; // In this demo, we do not write the SRAM. However, if
                             // you set 'sram_we' to 0, Vivado fails to synthesize
                             // ram0 as a BRAM -- this is a bug in Vivado.
assign sram_en = 1;          // Here, we always enable the SRAM block.
assign sram_addr = pixel_addr;
assign sram_addr_transparent = pixel_addr_transparent;
assign sram2_addr1 = pixel_fish2_addr;
assign sram2_addr2 = pixel_fish3_addr;
assign data_in = 12'h000; // SRAM is read-only so we tie inputs to zeros.
assign data_in_transparent = 12'h000;
// End of the SRAM memory block.
// ------------------------------------------------------------------------

// VGA color pixel generator
assign {VGA_RED, VGA_GREEN, VGA_BLUE} = rgb_reg;

// ------------------------------------------------------------------------
// An animation clock for the motion of the fish, upper bits of the
// fish clock is the x position of the fish on the VGA screen.
// Note that the fish will move one screen pixel every 2^20 clock cycles,
// or 10.49 msec
assign pos1 = fish1_clock[31:20]; // the x position of the right edge of the fish image
                                // in the 640x480 VGA screen
assign FISH_VPOS2 = fish2_clock[31:22];
assign FISH_VPOS3 = fish3_clock[31:22];
assign pos2 = fish2_clock[31:20];
assign pos3 = fish3_clock[31:20];
always @(posedge clk) begin
  if (~reset_n || fish1_clock[31:21] > VBUF_W + FISH_W) // clock divided by 2 since in VB
    fish1_clock <= 0;
  else
    fish1_clock <= (reverse ? fish1_clock - 1 * speed : fish1_clock + 1 * speed);
end
always @(posedge clk) begin
  if (~reset_n || fish2_clock[31:21] > VBUF_W + FISH_W)
    fish2_clock <= 0;
  else 
    fish2_clock <= (reverse ? fish2_clock - 2 * speed : fish2_clock + 2 * speed);
end
always @(posedge clk) begin
  if (~reset_n || fish3_clock[31:21] > VBUF_W + FISH_W) 
    fish3_clock <= 0;
  else 
    fish3_clock <= (reverse ? fish3_clock - 3 * speed : fish3_clock + 3 * speed);
end
// End of the animation clock code.
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// Video frame buffer address generation unit (AGU) with scaling control
// Note that the width x height of the fish image is 64x32, when scaled-up
// on the screen, it becomes 128x64. 'pos' specifies the right edge of the
// fish image.
assign fish1_region =
           pixel_y >= (FISH_VPOS1 << 1) && 
           pixel_y < ((FISH_VPOS1 + FISH_H1) << 1) &&
           (pixel_x + 127) >= pos1 && 
           pixel_x < pos1 + 1;

assign fish2_region = 
           pixel_y >= (FISH_VPOS2 << 1) && 
           pixel_y < ((FISH_VPOS2 + FISH_H2) << 1) && 
           (pixel_x + 127) >= pos2 && 
           pixel_x < pos2 + 1;

assign fish3_region = 
           pixel_y >= (FISH_VPOS3 << 1) && 
           pixel_y < ((FISH_VPOS3 + FISH_H3) << 1) && 
           (pixel_x + 127) >= pos3 && 
           pixel_x < pos3 + 1;

always @(posedge clk) begin 
  if (~reset_n)
    pixel_addr <= 0;
  else if (fish1_region)
    pixel_addr <= fish1_addr[fish1_clock[25:23]] +
                  ((pixel_y >> 1) - FISH_VPOS1) * FISH_W +
                  ((pixel_x + (FISH_W * 2 - 1) - pos1) >> 1);
  else 
    pixel_addr <= fish1_addr[0];
end
always @(posedge clk) begin
  if (~reset_n)
    pixel_addr_transparent <= 0;
  else 
    pixel_addr_transparent <= (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
end
always @(posedge clk) begin 
  if (~reset_n)
    pixel_fish2_addr <= 0;
  else if (fish2_region)
    pixel_fish2_addr <= fish2_addr[fish2_clock[25:23]] + 
                  ((pixel_y >> 1) - FISH_VPOS2) * FISH_W + 
                  ((pixel_x + (FISH_W * 2 - 1) - pos2) >> 1);
  else 
    pixel_fish2_addr <= fish2_addr[0];
end
always @(posedge clk) begin
  if (~reset_n)
    pixel_fish3_addr <= 0;
  else if (fish3_region)
    pixel_fish3_addr <= fish3_addr[fish3_clock[25:23]] +
                  ((pixel_y >> 1) - FISH_VPOS3) * FISH_W +
                  ((pixel_x + (FISH_W * 2 - 1) - pos3) >> 1);
  else 
    pixel_fish3_addr <= fish3_addr[0];
end

// End of the AGU code.
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// Send the video data in the sram to the VGA controller
always @(posedge clk) begin
  if (pixel_tick) 
    rgb_reg <= rgb_next;
  else 
    rgb_reg <= rgb_reg;
end

reg [11 : 0] data;
always @(*) begin 
  if (data_out != 12'h0F0)
    data = data_out;
  else if (data_out_fish2 != 12'h0F0)
    data = data_out_fish2;
  else if (data_out_fish3 != 12'h0F0)
    data = data_out_fish3;
  else 
    data = data_out_transparent; 
end
always @(*) begin
  if (~video_on)
    rgb_next = 12'h000; // Synchronization period, must set RGB values to zero.
  else 
    rgb_next = data;
end
// End of the video data display code.
// ------------------------------------------------------------------------
always @(posedge clk) begin 
  if (~reset_n)
    speed <= 1;
  else if (btn_pressed[1])
    speed <= (speed == 1 ? 1 : speed - 1);
  else if (btn_pressed[0])
    speed <= (speed == 7 ? 7 : speed + 1);
  else 
    speed <= speed;
end

always @(posedge clk) begin 
  if (~reset_n) 
    reverse <= 0;
  else 
    reverse <= (btn_pressed[2] ? ~reverse : reverse);
end
endmodule
