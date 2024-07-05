`timescale 1ns / 1ps
`define ROL32(x, c) (((x) << (c)) | ((x) >> (32 - (c))))

module random_number_generator (
  input clk,
  input reset_n,
  output reg [31:0] rng
);
  reg [31:0] SEED [0:1];
  initial begin
    SEED[0] = 32'hFACEB00C;
    SEED[1] = 32'hDEADBEEF;
  end
  reg [31:0] s [0:1];
  wire [31:0] xs;
  assign xs = s[0] ^ s[1];
  always @(posedge clk)
    if (~reset_n) begin
      s[0] <= SEED[0];
      s[1] <= SEED[1];
    end else begin
      s[0] <= `ROL32(xs, 19);
      s[1] <= `ROL32(s[0], 12) ^ xs ^ (xs << 8);
    end
  always @(posedge clk)
    rng <= ~reset_n ? 0 : s[0] + s[1];
endmodule
