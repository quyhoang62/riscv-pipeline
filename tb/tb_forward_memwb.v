`timescale 1ns/1ps

module tb_forward_memwb;
    reg clk = 0;
    reg rst = 1;
    integer err;
    reg seen_memwb_forward;

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
            // sub x4, x3, x1 after one nop -> should pick x3 from MEM/WB
            if (dut.id_ex_opcode_q == 7'b0110011 && dut.id_ex_rs1_q == 5'd3 && dut.id_ex_rs2_q == 5'd1 && dut.id_ex_rd_q == 5'd4) begin
                if (dut.fwd_a == 2'b01)
                    seen_memwb_forward <= 1'b1;
            end
        end
    end

    initial begin
        $dumpfile("sim/tb_forward_memwb.vcd");
        $dumpvars(0, tb_forward_memwb);
        err = 0;
        seen_memwb_forward = 0;

        dut.u_imem.mem[0] = enc_i(12'd3, 5'd0, 3'b000, 5'd1, 7'b0010011); // addi x1,3
        dut.u_imem.mem[1] = enc_i(12'd4, 5'd0, 3'b000, 5'd2, 7'b0010011); // addi x2,4
        dut.u_imem.mem[2] = enc_r(7'b0000000,5'd2,5'd1,3'b000,5'd3,7'b0110011); // add x3,7
        dut.u_imem.mem[3] = 32'h0000_0013; // nop
        dut.u_imem.mem[4] = enc_r(7'b0100000,5'd1,5'd3,3'b000,5'd4,7'b0110011); // sub x4,x3,x1 => 4

        #30;
        rst = 0;

        repeat (35) @(posedge clk);

        if (!seen_memwb_forward) begin $display("FAIL did not observe MEM/WB forward on input A"); err = err + 1; end
        if (dut.u_rf.regs[4] !== 32'd4) begin $display("FAIL x4=%h expected 4", dut.u_rf.regs[4]); err = err + 1; end

        if (err == 0)
            $display("PASS: tb_forward_memwb");
        else
            $display("FAIL: tb_forward_memwb (%0d errors)", err);

        $finish;
    end
endmodule
