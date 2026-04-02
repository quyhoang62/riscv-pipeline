module branch_comp (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [2:0]  funct3,
    output reg         take
);
    always @(*) begin
        case (funct3)
            3'b000: take = (a == b);                    // beq
            3'b001: take = (a != b);                    // bne
            3'b100: take = ($signed(a) < $signed(b));   // blt
            3'b101: take = ($signed(a) >= $signed(b));  // bge
            3'b110: take = (a < b);                     // bltu
            3'b111: take = (a >= b);                    // bgeu
            default: take = 1'b0;
        endcase
    end
endmodule

