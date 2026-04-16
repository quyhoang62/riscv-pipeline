`timescale 1ns/1ps

module tb_branch_data_hazard;
    reg clk = 0;
    reg rst = 1;
    integer err;
    reg branch_taken_seen;
    reg fwd_for_branch_seen;

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
        if (!rst) begin
            if (dut.id_ex_opcode_q == 7'b1100011 && dut.id_ex_rs1_q == 5'd3 && dut.fwd_a == 2'b10)
                fwd_for_branch_seen <= 1'b1;
            if (dut.ex_taken)
                branch_taken_seen <= 1'b1;
        end
    end

    initial begin
        $dumpfile("sim/tb_branch_data_hazard.vcd");
        $dumpvars(0, tb_branch_data_hazard);
        err = 0;
        branch_taken_seen = 0;
        fwd_for_branch_seen = 0;

        dut.u_imem.mem[0] = enc_i(12'd5, 5'd0, 3'b000, 5'd1, 7'b0010011); // addi x1,5
        dut.u_imem.mem[1] = enc_i(12'd5, 5'd0, 3'b000, 5'd2, 7'b0010011); // addi x2,5
        dut.u_imem.mem[2] = enc_r(7'b0100000,5'd2,5'd1,3'b000,5'd3,7'b0110011); // sub x3,x1,x2 => 0
        dut.u_imem.mem[3] = enc_b(8, 5'd0, 5'd3, 3'b000); // beq x3,x0,+8
        dut.u_imem.mem[4] = enc_i(12'd9, 5'd0, 3'b000, 5'd4, 7'b0010011); // wrong path
        dut.u_imem.mem[5] = enc_i(12'd1, 5'd0, 3'b000, 5'd5, 7'b0010011); // target

        #30;
        rst = 0;

        repeat (40) @(posedge clk);

        if (!fwd_for_branch_seen) begin $display("FAIL no forwarding observed for branch compare operand"); err = err + 1; end
        if (!branch_taken_seen) begin $display("FAIL branch not taken when x3==0"); err = err + 1; end
        if (dut.u_rf.regs[4] !== 32'd0) begin $display("FAIL x4=%h expected 0", dut.u_rf.regs[4]); err = err + 1; end
        if (dut.u_rf.regs[5] !== 32'd1) begin $display("FAIL x5=%h expected 1", dut.u_rf.regs[5]); err = err + 1; end

        if (err == 0)
            $display("PASS: tb_branch_data_hazard");
        else
            $display("FAIL: tb_branch_data_hazard (%0d errors)", err);

        $finish;
    end
endmodule
