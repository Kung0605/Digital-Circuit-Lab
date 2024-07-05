module alu (
    output reg [7 : 0]  alu_out, 
    output                    zero,
    input [2 : 0]            opcode,
    input [7 : 0]            data,
    input [7 : 0]            accum,
    input                       clk,
    input                       reset
);
    always @(posedge clk) begin 
        if (reset) begin 
            alu_out <= 8'b0;
        end
        else begin 
            casez(opcode)
                    3'b000: alu_out <= accum;
                    3'b001: alu_out <= $signed(accum) + $signed(data);
                    3'b010: alu_out <= $signed(accum) - $signed(data);
                    3'b011: alu_out <= accum & data;
                    3'b100: alu_out <= accum ^ data;
                    3'b101: alu_out <= ($signed(accum) > 0 ? accum : -$signed(accum));
                    3'b110: alu_out <= $signed(accum[3 : 0]) * $signed(data[3 : 0]);
                    3'b111: alu_out <= data;
                    default:alu_out <= 8'b0;
            endcase
        end
    end
    assign zero = (accum == 8'b0);
endmodule