module controller (
    input  wire [31:0] instr,
    output reg         regwrite,
    output reg         memread,
    output reg         memwrite,
    output reg         memtoreg,
    output reg  [1:0]  aluop,
    output reg         alusrc,
    output reg         branch,
    output reg         jump,
    output reg         jalr,
    output reg         lui,
    output reg         auipc
);
    wire [6:0] opcode = instr[6:0];

    always @(*) begin
        regwrite = 1'b0;
        memread  = 1'b0;
        memwrite = 1'b0;
        memtoreg = 1'b0;
        aluop    = 2'b00;
        alusrc   = 1'b0;
        branch   = 1'b0;
        jump     = 1'b0;
        jalr     = 1'b0;
        lui      = 1'b0;
        auipc    = 1'b0;

        case (opcode)
            7'b0110011: begin // R-type
                regwrite = 1'b1;
                aluop    = 2'b10;
                alusrc   = 1'b0;
            end
            7'b0010011: begin // I-type ALU
                regwrite = 1'b1;
                aluop    = 2'b11;
                alusrc   = 1'b1;
            end
            7'b0000011: begin // LOAD
                regwrite = 1'b1;
                memread  = 1'b1;
                memtoreg = 1'b1;
                aluop    = 2'b00; // add for address
                alusrc   = 1'b1;
            end
            7'b0100011: begin // STORE
                memwrite = 1'b1;
                aluop    = 2'b00; // add for address
                alusrc   = 1'b1;
            end
            7'b1100011: begin // BRANCH
                branch = 1'b1;
                aluop  = 2'b01; // subtract/compare
                alusrc = 1'b0;
            end
            7'b1101111: begin // JAL
                jump     = 1'b1;
                regwrite = 1'b1;
            end
            7'b1100111: begin // JALR
                jump     = 1'b1;
                jalr     = 1'b1;
                regwrite = 1'b1;
                alusrc   = 1'b1;
                aluop    = 2'b00; // base + imm
            end
            7'b0110111: begin // LUI
                lui      = 1'b1;
                regwrite = 1'b1;
            end
            7'b0010111: begin // AUIPC
                auipc    = 1'b1;
                regwrite = 1'b1;
            end
            default: begin end
        endcase
    end
endmodule

