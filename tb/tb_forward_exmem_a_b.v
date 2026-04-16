`timescale 1ns/1ps

module tb_forward_exmem_a_b;
    reg clk = 0;
    reg rst = 1;
    integer err;
    reg seen_a10;
    reg seen_b10;

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

    always @(posedge clk) begin
        if (!rst) begin
            // sub x4, x3, x1 -> rs1 needs EX/MEM forward from x3
            if (dut.id_ex_opcode_q == 7'b0110011 && dut.id_ex_rs1_q == 5'd3 && dut.id_ex_rs2_q == 5'd1 && dut.id_ex_rd_q == 5'd4) begin
                if (dut.fwd_a == 2'b10)
                    seen_a10 <= 1'b1;
            end

            // sub x4, x1, x3 -> rs2 needs EX/MEM forward from x3
            if (dut.id_ex_opcode_q == 7'b0110011 && dut.id_ex_rs1_q == 5'd1 && dut.id_ex_rs2_q == 5'd3 && dut.id_ex_rd_q == 5'd4) begin
                if (dut.fwd_b == 2'b10)
                    seen_b10 <= 1'b1;
            end
        end
    end

    initial begin
        $dumpfile("sim/tb_forward_exmem_a_b.vcd");
        $dumpvars(0, tb_forward_exmem_a_b);
        err = 0;
        seen_a10 = 0;
        seen_b10 = 0;

        // Sequence A: EX/MEM -> A
        dut.u_imem.mem[0] = enc_i(12'd10, 5'd0, 3'b000, 5'd1, 7'b0010011); // addi x1,10
        dut.u_imem.mem[1] = enc_i(12'd20, 5'd0, 3'b000, 5'd2, 7'b0010011); // addi x2,20
        dut.u_imem.mem[2] = enc_r(7'b0000000,5'd2,5'd1,3'b000,5'd3,7'b0110011); // add x3,x1,x2
        dut.u_imem.mem[3] = enc_r(7'b0100000,5'd1,5'd3,3'b000,5'd4,7'b0110011); // sub x4,x3,x1 => 20

        // Sequence B: EX/MEM -> B
        dut.u_imem.mem[4] = enc_i(12'd8,  5'd0,3'b000,5'd1,7'b0010011); // addi x1,8
        dut.u_imem.mem[5] = enc_i(12'd4,  5'd0,3'b000,5'd2,7'b0010011); // addi x2,4
        dut.u_imem.mem[6] = enc_r(7'b0000000,5'd2,5'd1,3'b000,5'd3,7'b0110011); // add x3,12
        dut.u_imem.mem[7] = enc_r(7'b0100000,5'd3,5'd1,3'b000,5'd4,7'b0110011); // sub x4,x1,x3 => -4

        #30;
        rst = 0;

        repeat (45) @(posedge clk);

        if (!seen_a10) begin $display("FAIL did not observe fwd_a=10 for EX/MEM path"); err = err + 1; end
        if (!seen_b10) begin $display("FAIL did not observe fwd_b=10 for EX/MEM path"); err = err + 1; end

        // Last sequence overwrites x4 with -4.
        if (dut.u_rf.regs[4] !== 32'hffff_fffc) begin $display("FAIL x4=%h expected ffffffff...fffc", dut.u_rf.regs[4]); err = err + 1; end

        if (err == 0)
            $display("PASS: tb_forward_exmem_a_b");
        else
            $display("FAIL: tb_forward_exmem_a_b (%0d errors)", err);

        $finish;
    end
endmodule
