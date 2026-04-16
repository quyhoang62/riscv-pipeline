`timescale 1ns/1ps

module tb_store_load_wb;
    reg clk = 0;
    reg rst = 1;
    integer err;
    reg seen_memwrite;
    reg seen_memread;

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
            if (dut.ex_mem_memwrite_q)
                seen_memwrite <= 1'b1;
            if (dut.ex_mem_memread_q)
                seen_memread <= 1'b1;
        end
    end

    initial begin
        $dumpfile("sim/tb_store_load_wb.vcd");
        $dumpvars(0, tb_store_load_wb);
        err = 0;
        seen_memwrite = 0;
        seen_memread = 0;

        dut.u_imem.mem[0] = enc_i(12'd100, 5'd0, 3'b000, 5'd1, 7'b0010011); // addi x1,100
        dut.u_imem.mem[1] = enc_i(12'd55,  5'd0, 3'b000, 5'd2, 7'b0010011); // addi x2,55
        dut.u_imem.mem[2] = enc_s(12'd0,   5'd2, 5'd1, 3'b010, 7'b0100011); // sw x2,0(x1)
        dut.u_imem.mem[3] = enc_i(12'd0,   5'd1, 3'b010, 5'd3, 7'b0000011); // lw x3,0(x1)

        #30;
        rst = 0;

        repeat (35) @(posedge clk);

        if (!seen_memwrite) begin $display("FAIL memwrite not seen"); err = err + 1; end
        if (!seen_memread) begin $display("FAIL memread not seen"); err = err + 1; end
        if (dut.u_rf.regs[3] !== 32'd55) begin $display("FAIL x3=%h expected 55", dut.u_rf.regs[3]); err = err + 1; end

        if ({dut.u_dmem.mem[103], dut.u_dmem.mem[102], dut.u_dmem.mem[101], dut.u_dmem.mem[100]} !== 32'd55) begin
            $display("FAIL mem[100]=%h", {dut.u_dmem.mem[103], dut.u_dmem.mem[102], dut.u_dmem.mem[101], dut.u_dmem.mem[100]});
            err = err + 1;
        end

        if (err == 0)
            $display("PASS: tb_store_load_wb");
        else
            $display("FAIL: tb_store_load_wb (%0d errors)", err);

        $finish;
    end
endmodule
