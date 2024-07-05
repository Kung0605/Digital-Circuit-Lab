module padding(
    input [63 : 0] passwd,
    output [0 : 959] chunk
);
    assign chunk[0 : 63] = passwd[63 : 0];
    assign chunk[64 +: 8] = 128;
    assign chunk[72 +: 376] = 0;
    assign chunk[448 +: 8] = 64;
    assign chunk[456 : 959] = 0;
endmodule