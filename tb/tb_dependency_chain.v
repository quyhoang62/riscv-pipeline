`timescale 1ns/1ps

module tb_dependency_chain;
    reg clk = 0;
    reg rst = 1;
    integer err;
    integer fwd_count;

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

    always @(posedge clk) begin
        if (!rst) begin
            if ((dut.fwd_a != 2'b00) || (dut.fwd_b != 2'b00))
                fwd_count <= fwd_count + 1;
        end
    end

    initial begin
        $dumpfile("sim/tb_dependency_chain.vcd");
        $dumpvars(0, tb_dependency_chain);
        err = 0;
        fwd_count = 0;

        // Long RAW dependency chain
        dut.u_imem.mem[0] = enc_i(12'd1, 5'd0, 3'b000, 5'd1, 7'b0010011); // x1=1
        dut.u_imem.mem[1] = enc_i(12'd2, 5'd1, 3'b000, 5'd2, 7'b0010011); // x2=3
        dut.u_imem.mem[2] = enc_i(12'd3, 5'd2, 3'b000, 5'd3, 7'b0010011); // x3=6
        dut.u_imem.mem[3] = enc_i(12'd4, 5'd3, 3'b000, 5'd4, 7'b0010011); // x4=10
        dut.u_imem.mem[4] = enc_i(12'd5, 5'd4, 3'b000, 5'd5, 7'b0010011); // x5=15

        #30;
        rst = 0;

        repeat (35) @(posedge clk);

        if (dut.u_rf.regs[1] !== 32'd1)  begin $display("FAIL x1=%h", dut.u_rf.regs[1]); err = err + 1; end
        if (dut.u_rf.regs[2] !== 32'd3)  begin $display("FAIL x2=%h", dut.u_rf.regs[2]); err = err + 1; end
        if (dut.u_rf.regs[3] !== 32'd6)  begin $display("FAIL x3=%h", dut.u_rf.regs[3]); err = err + 1; end
        if (dut.u_rf.regs[4] !== 32'd10) begin $display("FAIL x4=%h", dut.u_rf.regs[4]); err = err + 1; end
        if (dut.u_rf.regs[5] !== 32'd15) begin $display("FAIL x5=%h", dut.u_rf.regs[5]); err = err + 1; end
        if (fwd_count < 3) begin $display("FAIL forwarding activity too low: %0d", fwd_count); err = err + 1; end

        if (err == 0)
            $display("PASS: tb_dependency_chain");
        else
            $display("FAIL: tb_dependency_chain (%0d errors)", err);

        $finish;
    end
endmodule
