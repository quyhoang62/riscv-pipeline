module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  alu_ctrl,
    output reg  [31:0] y,
    output wire        zero
);
    // alu_ctrl encoding:
    // 0000 ADD, 0001 SUB, 0010 AND, 0011 OR, 0100 XOR
    // 0101 SLL, 0110 SRL, 0111 SRA, 1000 SLT, 1001 SLTU
    always @(*) begin
        case (alu_ctrl)
            4'b0000: y = a + b;
            4'b0001: y = a - b;
            4'b0010: y = a & b;
            4'b0011: y = a | b;
            4'b0100: y = a ^ b;
            4'b0101: y = a << b[4:0];
            4'b0110: y = a >> b[4:0];
            4'b0111: y = $signed(a) >>> b[4:0];
            4'b1000: y = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            4'b1001: y = (a < b) ? 32'd1 : 32'd0;
            default: y = 32'd0;
        endcase
    end

    assign zero = (y == 32'd0);
endmodule

