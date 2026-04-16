`timescale 1ns/1ps

module tb_x0_cornercase;
    reg clk = 0;
    reg rst = 1;
    integer err;
    reg no_forward_rd0_seen;

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
            // sub x3, x0, x1 should not forward from prior rd=x0
            if (dut.id_ex_opcode_q == 7'b0110011 && dut.id_ex_rs1_q == 5'd0 && dut.id_ex_rs2_q == 5'd1 && dut.id_ex_rd_q == 5'd3) begin
                if (dut.fwd_a == 2'b00)
                    no_forward_rd0_seen <= 1'b1;
            end
        end
    end

    initial begin
        $dumpfile("sim/tb_x0_cornercase.vcd");
        $dumpvars(0, tb_x0_cornercase);
        err = 0;
        no_forward_rd0_seen = 0;

        dut.u_imem.mem[0] = enc_i(12'd5, 5'd0, 3'b000, 5'd0, 7'b0010011); // addi x0,x0,5 (ignored)
        dut.u_imem.mem[1] = enc_i(12'd3, 5'd0, 3'b000, 5'd1, 7'b0010011); // addi x1,3
        dut.u_imem.mem[2] = enc_r(7'b0000000,5'd1,5'd1,3'b000,5'd0,7'b0110011); // add x0,x1,x1 (ignored)
        dut.u_imem.mem[3] = enc_r(7'b0100000,5'd1,5'd0,3'b000,5'd3,7'b0110011); // sub x3,x0,x1 => -3

        #30;
        rst = 0;

        repeat (35) @(posedge clk);

        if (dut.u_rf.regs[0] !== 32'd0) begin $display("FAIL x0=%h expected 0", dut.u_rf.regs[0]); err = err + 1; end
        if (dut.u_rf.regs[1] !== 32'd3) begin $display("FAIL x1=%h expected 3", dut.u_rf.regs[1]); err = err + 1; end
        if (dut.u_rf.regs[3] !== 32'hffff_fffd) begin $display("FAIL x3=%h expected -3", dut.u_rf.regs[3]); err = err + 1; end
        if (!no_forward_rd0_seen) begin $display("FAIL forwarding from rd=0 was not properly suppressed"); err = err + 1; end

        if (err == 0)
            $display("PASS: tb_x0_cornercase");
        else
            $display("FAIL: tb_x0_cornercase (%0d errors)", err);

        $finish;
    end
endmodule
