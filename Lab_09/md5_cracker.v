module md5_cracker(
    input clk,
    input reset_n,
    input clear,
    input [0 : 63] pwd_in,
    
    output [0 : 127] result,
    output finish,
    output correct
);
    function [31 : 0] LEFTROTATE(input [31 : 0] x, input [7 : 0] c);
        LEFTROTATE = (x << c) | (x >> (32 - c));
    endfunction
    wire [0 : 959] chunk;
    padding padding_t(.passwd(pwd_in), .chunk(chunk));
    reg [31 : 0] h0 = 32'h67452301,
                      h1 = 32'hefcdab89,
                      h2 = 32'h98badcfe,
                      h3 = 32'h10325476;
    reg [31 : 0] a = 0, b = 0, c = 0, d = 0;
    reg [31 : 0] f, g;
    reg [31 : 0] i;
    reg [7 : 0] r [0 : 63];
    reg [31 : 0] k [0 : 63];
    reg [31 : 0] w [0 : 15];
    wire [7 : 0] offset = 0;
    integer idx;
    always @(*) begin
        for (idx = 0; idx < 16; idx = idx + 1) begin
            w[idx] = {chunk[idx * 32 + 24 +: 8], 
                           chunk[idx * 32 + 16 +: 8],
                           chunk[idx * 32 +   8 +: 8],
                           chunk[idx * 32 +   0 +: 8]};
        end
    end
    always @(posedge clk) begin
        if ((~reset_n) | clear)
            i <= 0;
        else 
            i <= i + 1; 
    end
    always @(*) begin
        if (~reset_n) begin
            f = 32'b0;
            g = 32'b0;
        end
        else if (i < 16) begin
            f = (b & c) | ((~b) & d);
            g = i;
        end
        else if (i < 32) begin
            f = (d & b) | ((~d) & c);
            g = (5*i + 1) % 16;
        end
        else if (i < 48) begin
            f = b ^ c ^ d;
            g = (3*i + 5) % 16;  
        end 
        else begin
            f = c ^ (b | (~d));
            g = (7*i) % 16;
        end  
    end
    always @(posedge clk) begin
        if ((~reset_n) | clear) begin
            a <= 32'h67452301;
            b <= 32'hefcdab89;
            c <= 32'h98badcfe;
            d <= 32'h10325476;
        end
        else begin
            a <= d;
            b <= b + LEFTROTATE(a + f + k[i] + w[g], r[i]);
            c <= b;
            d <= c;
        end
    end
    always @(posedge clk) begin
        if ((~reset_n) | clear) begin
            h0 <= 32'h67452301;
            h1 <= 32'hefcdab89;
            h2 <= 32'h98badcfe;
            h3 <= 32'h10325476;
        end
        else if (i == 32'd64) begin
            h0 <= h0 + a;
            h1 <= h1 + b;
            h2 <= h2 + c;
            h3 <= h3 + d;
        end
        else begin
            h0 <= h0;
            h1 <= h1;
            h2 <= h2;
            h3 <= h3;
        end
    end
    initial begin
        r[0] = 8'd7;  r[1] = 8'd12;  r[2] = 8'd17;  r[3] = 8'd22;
        r[4] = 8'd7;  r[5] = 8'd12;  r[6] = 8'd17;  r[7] = 8'd22;
        r[8] = 8'd7;  r[9] = 8'd12;  r[10] = 8'd17; r[11] = 8'd22;
        r[12] = 8'd7; r[13] = 8'd12;  r[14] = 8'd17; r[15] = 8'd22;
        r[16] = 8'd5; r[17] = 8'd9;   r[18] = 8'd14; r[19] = 8'd20;
        r[20] = 8'd5; r[21] = 8'd9;   r[22] = 8'd14; r[23] = 8'd20;
        r[24] = 8'd5; r[25] = 8'd9;   r[26] = 8'd14; r[27] = 8'd20;
        r[28] = 8'd5; r[29] = 8'd9;   r[30] = 8'd14; r[31] = 8'd20;
        r[32] = 8'd4; r[33] = 8'd11;  r[34] = 8'd16; r[35] = 8'd23;
        r[36] = 8'd4; r[37] = 8'd11;  r[38] = 8'd16; r[39] = 8'd23;
        r[40] = 8'd4; r[41] = 8'd11;  r[42] = 8'd16; r[43] = 8'd23;
        r[44] = 8'd4; r[45] = 8'd11;  r[46] = 8'd16; r[47] = 8'd23;
        r[48] = 8'd6; r[49] = 8'd10;  r[50] = 8'd15; r[51] = 8'd21;
        r[52] = 8'd6; r[53] = 8'd10;  r[54] = 8'd15; r[55] = 8'd21;
        r[56] = 8'd6; r[57] = 8'd10;  r[58] = 8'd15; r[59] = 8'd21;
        r[60] = 8'd6; r[61] = 8'd10;  r[62] = 8'd15; r[63] = 8'd21;
    end
    initial begin
        k[0]  = 32'hd76aa478; k[1]  = 32'he8c7b756; k[2]  = 32'h242070db; k[3]  = 32'hc1bdceee;
        k[4]  = 32'hf57c0faf; k[5]  = 32'h4787c62a; k[6]  = 32'ha8304613; k[7]  = 32'hfd469501;
        k[8]  = 32'h698098d8; k[9]  = 32'h8b44f7af; k[10] = 32'hffff5bb1; k[11] = 32'h895cd7be;
        k[12] = 32'h6b901122; k[13] = 32'hfd987193; k[14] = 32'ha679438e; k[15] = 32'h49b40821;
        k[16] = 32'hf61e2562; k[17] = 32'hc040b340; k[18] = 32'h265e5a51; k[19] = 32'he9b6c7aa;
        k[20] = 32'hd62f105d; k[21] = 32'h02441453; k[22] = 32'hd8a1e681; k[23] = 32'he7d3fbc8;
        k[24] = 32'h21e1cde6; k[25] = 32'hc33707d6; k[26] = 32'hf4d50d87; k[27] = 32'h455a14ed;
        k[28] = 32'ha9e3e905; k[29] = 32'hfcefa3f8; k[30] = 32'h676f02d9; k[31] = 32'h8d2a4c8a;
        k[32] = 32'hfffa3942; k[33] = 32'h8771f681; k[34] = 32'h6d9d6122; k[35] = 32'hfde5380c;
        k[36] = 32'ha4beea44; k[37] = 32'h4bdecfa9; k[38] = 32'hf6bb4b60; k[39] = 32'hbebfbc70;
        k[40] = 32'h289b7ec6; k[41] = 32'heaa127fa; k[42] = 32'hd4ef3085; k[43] = 32'h04881d05;
        k[44] = 32'hd9d4d039; k[45] = 32'he6db99e5; k[46] = 32'h1fa27cf8; k[47] = 32'hc4ac5665;
        k[48] = 32'hf4292244; k[49] = 32'h432aff97; k[50] = 32'hab9423a7; k[51] = 32'hfc93a039;
        k[52] = 32'h655b59c3; k[53] = 32'h8f0ccc92; k[54] = 32'hffeff47d; k[55] = 32'h85845dd1;
        k[56] = 32'h6fa87e4f; k[57] = 32'hfe2ce6e0; k[58] = 32'ha3014314; k[59] = 32'h4e0811a1;
        k[60] = 32'hf7537e82; k[61] = 32'hbd3af235; k[62] = 32'h2ad7d2bb; k[63] = 32'heb86d391;
    end
    assign finish = (i == 65);
    /*assign result = {h0[7  :  0], h0[15 :  8], h0[23: 15], h0[31 : 24],
                     h1[7  :  0], h1[15 :  8], h1[23: 15], h1[31 : 24],
                     h2[7  :  0], h2[15 :  8], h2[23: 15], h2[31 : 24],
                     h3[7  :  0], h3[15 :  8], h3[23: 15], h3[31 : 24]};*/
    assign result = {h0[7 : 0], h0[15 : 8], h0[23 : 16], h0[31 : 24],
                     h1[7 : 0], h1[15 : 8], h1[23 : 16], h1[31 : 24], 
                     h2[7 : 0], h2[15 : 8], h2[23 : 16], h2[31 : 24], 
                     h3[7 : 0], h3[15 : 8], h3[23 : 16], h3[31 : 24]};            
                           
    assign correct = (result == 128'hE8CD0953ABDFDE433DFEC7FAA70DF7F6);
endmodule