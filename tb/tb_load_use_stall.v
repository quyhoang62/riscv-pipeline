`timescale 1ns/1ps

module tb_load_use_stall;
    reg clk = 0;
    reg rst = 1;
    integer err;
    reg stall_seen;
    reg pc_hold_ok;
    reg        check_pc_hold_next;
    reg [31:0] stall_pc;

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

    function [31:0] enc_s;
        input [11:0] imm;
        input [4:0] rs2;
        input [4:0] rs1;
        input [2:0] funct3;
        input [6:0] opcode;
        begin
            enc_s = {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode};
        end
    endfunction

    always @(posedge clk) begin
        if (!rst) begin
            if (check_pc_hold_next) begin
                if (dut.pc_q !== stall_pc)
                    pc_hold_ok <= 1'b0;
                check_pc_hold_next <= 1'b0;
            end

            if (dut.load_use_stall == 1'b1) begin
                stall_seen <= 1'b1;
                stall_pc <= dut.pc_q;
                check_pc_hold_next <= 1'b1;
            end
        end
    end

    initial begin
        $dumpfile("sim/tb_load_use_stall.vcd");
        $dumpvars(0, tb_load_use_stall);
        err = 0;
        stall_seen = 0;
        pc_hold_ok = 1;
        check_pc_hold_next = 0;
        stall_pc = 0;

        // Data memory[0] = 7 (little-endian)
        dut.u_dmem.mem[0] = 8'h07;
        dut.u_dmem.mem[1] = 8'h00;
        dut.u_dmem.mem[2] = 8'h00;
        dut.u_dmem.mem[3] = 8'h00;

        dut.u_imem.mem[0] = enc_i(12'd0, 5'd0, 3'b000, 5'd1, 7'b0010011); // addi x1,0
        dut.u_imem.mem[1] = enc_i(12'd5, 5'd0, 3'b000, 5'd2, 7'b0010011); // addi x2,5
        dut.u_imem.mem[2] = enc_i(12'd0, 5'd1, 3'b010, 5'd3, 7'b0000011); // lw x3,0(x1)
        dut.u_imem.mem[3] = enc_r(7'b0000000,5'd2,5'd3,3'b000,5'd4,7'b0110011); // add x4,x3,x2
        dut.u_imem.mem[4] = enc_s(12'd4, 5'd4, 5'd1, 3'b010, 7'b0100011); // sw x4,4(x1) (optional use)

        #30;
        rst = 0;

        repeat (45) @(posedge clk);

        if (!stall_seen) begin $display("FAIL stall not observed on load-use hazard"); err = err + 1; end
        if (!pc_hold_ok) begin $display("FAIL PC advanced during stall cycle"); err = err + 1; end
        if (dut.u_rf.regs[3] !== 32'd7) begin $display("FAIL x3=%h expected 7", dut.u_rf.regs[3]); err = err + 1; end
        if (dut.u_rf.regs[4] !== 32'd12) begin $display("FAIL x4=%h expected 12", dut.u_rf.regs[4]); err = err + 1; end

        if (err == 0)
            $display("PASS: tb_load_use_stall");
        else
            $display("FAIL: tb_load_use_stall (%0d errors)", err);

        $finish;
    end
endmodule
