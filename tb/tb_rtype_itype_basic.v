`timescale 1ns/1ps

module tb_rtype_itype_basic;
    reg clk = 0;
    reg rst = 1;
    integer err;

    pp_top dut (
        .clk(clk),
        .rst(rst)
    );

    always #5 clk = ~clk;

    function [31:0] enc_r;
        input [6:0] funct7;
        input [4:0] rs2;
        input [4:0] rs1;
        input [2:0] funct3;
        input [4:0] rd;
        input [6:0] opcode;
        begin
            enc_r = {funct7, rs2, rs1, funct3, rd, opcode};
        end
    endfunction

    function [31:0] enc_i;
        input [11:0] imm;
        input [4:0] rs1;
        input [2:0] funct3;
        input [4:0] rd;
        input [6:0] opcode;
        begin
            enc_i = {imm, rs1, funct3, rd, opcode};
        end
    endfunction

    initial begin
        $dumpfile("sim/tb_rtype_itype_basic.vcd");
        $dumpvars(0, tb_rtype_itype_basic);
        err = 0;

        // Program: basic decode/ALU/WB with spaced dependencies to avoid RAW hazards.
        dut.u_imem.mem[0] = enc_i(12'd5,  5'd0, 3'b000, 5'd1, 7'b0010011); // addi x1,x0,5
        dut.u_imem.mem[1] = enc_i(12'd7,  5'd0, 3'b000, 5'd2, 7'b0010011); // addi x2,x0,7
        dut.u_imem.mem[2] = 32'h0000_0013; // nop
        dut.u_imem.mem[3] = 32'h0000_0013; // nop
        dut.u_imem.mem[4] = enc_r(7'b0000000, 5'd2, 5'd1, 3'b000, 5'd3, 7'b0110011); // add x3,x1,x2 => 12
        dut.u_imem.mem[5] = enc_r(7'b0100000, 5'd1, 5'd2, 3'b000, 5'd4, 7'b0110011); // sub x4,x2,x1 => 2
        dut.u_imem.mem[6] = enc_r(7'b0000000, 5'd2, 5'd1, 3'b111, 5'd5, 7'b0110011); // and x5,x1,x2 => 5
        dut.u_imem.mem[7] = enc_r(7'b0000000, 5'd2, 5'd1, 3'b110, 5'd6, 7'b0110011); // or x6,x1,x2 => 7
        dut.u_imem.mem[8] = enc_i(12'd3,  5'd2, 3'b111, 5'd7, 7'b0010011); // andi x7,x2,3 => 3
        dut.u_imem.mem[9] = enc_i(12'd8,  5'd1, 3'b110, 5'd8, 7'b0010011); // ori x8,x1,8 => 13

        #30;
        rst = 0;

        repeat (30) @(posedge clk);

        if (dut.u_rf.regs[1] !== 32'd5)  begin $display("FAIL x1=%h", dut.u_rf.regs[1]); err = err + 1; end
        if (dut.u_rf.regs[2] !== 32'd7)  begin $display("FAIL x2=%h", dut.u_rf.regs[2]); err = err + 1; end
        if (dut.u_rf.regs[3] !== 32'd12) begin $display("FAIL x3=%h", dut.u_rf.regs[3]); err = err + 1; end
        if (dut.u_rf.regs[4] !== 32'd2)  begin $display("FAIL x4=%h", dut.u_rf.regs[4]); err = err + 1; end
        if (dut.u_rf.regs[5] !== 32'd5)  begin $display("FAIL x5=%h", dut.u_rf.regs[5]); err = err + 1; end
        if (dut.u_rf.regs[6] !== 32'd7)  begin $display("FAIL x6=%h", dut.u_rf.regs[6]); err = err + 1; end
        if (dut.u_rf.regs[7] !== 32'd3)  begin $display("FAIL x7=%h", dut.u_rf.regs[7]); err = err + 1; end
        if (dut.u_rf.regs[8] !== 32'd13) begin $display("FAIL x8=%h", dut.u_rf.regs[8]); err = err + 1; end

        if (err == 0)
            $display("PASS: tb_rtype_itype_basic");
        else
            $display("FAIL: tb_rtype_itype_basic (%0d errors)", err);

        $finish;
    end
endmodule
