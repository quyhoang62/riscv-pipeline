`timescale 1ns/1ps

module tb_branch_flush;
    reg clk = 0;
    reg rst = 1;
    integer err;
    reg flush_seen;

    pp_top dut (
        .clk(clk),
        .rst(rst)
    );

    always #5 clk = ~clk;

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

    function [31:0] enc_b;
        input integer byte_off;
        input [4:0] rs2;
        input [4:0] rs1;
        input [2:0] funct3;
        reg [12:0] imm;
        begin
            imm = byte_off[12:0];
            enc_b = {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], 7'b1100011};
        end
    endfunction

    always @(posedge clk) begin
        if (!rst && dut.ex_taken)
            flush_seen <= 1'b1;
    end

    initial begin
        $dumpfile("sim/tb_branch_flush.vcd");
        $dumpvars(0, tb_branch_flush);
        err = 0;
        flush_seen = 0;

        // Branch taken: skip two wrong-path instructions (x3 writes must be suppressed)
        dut.u_imem.mem[0] = enc_i(12'd5, 5'd0, 3'b000, 5'd1, 7'b0010011); // addi x1,5
        dut.u_imem.mem[1] = enc_i(12'd5, 5'd0, 3'b000, 5'd2, 7'b0010011); // addi x2,5
        dut.u_imem.mem[2] = enc_b(12, 5'd2, 5'd1, 3'b000); // beq x1,x2,+12 -> to mem[5]
        dut.u_imem.mem[3] = enc_i(12'd1, 5'd0, 3'b000, 5'd3, 7'b0010011); // wrong path
        dut.u_imem.mem[4] = enc_i(12'd9, 5'd0, 3'b000, 5'd3, 7'b0010011); // wrong path
        dut.u_imem.mem[5] = enc_i(12'd2, 5'd0, 3'b000, 5'd4, 7'b0010011); // L1: addi x4,2

        #30;
        rst = 0;

        repeat (40) @(posedge clk);

        if (!flush_seen) begin $display("FAIL flush not observed on taken branch"); err = err + 1; end
        if (dut.u_rf.regs[3] !== 32'd0) begin $display("FAIL x3=%h expected 0 (wrong-path write)", dut.u_rf.regs[3]); err = err + 1; end
        if (dut.u_rf.regs[4] !== 32'd2) begin $display("FAIL x4=%h expected 2", dut.u_rf.regs[4]); err = err + 1; end

        if (err == 0)
            $display("PASS: tb_branch_flush");
        else
            $display("FAIL: tb_branch_flush (%0d errors)", err);

        $finish;
    end
endmodule
