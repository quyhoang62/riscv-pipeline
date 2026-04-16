`timescale 1ns/1ps

module tb_pp_top;
    reg clk = 0;
    reg rst = 1;
    integer err;
    integer cycle;

    pp_top dut (
        .clk(clk),
        .rst(rst)
    );

    always #5 clk = ~clk; // 100MHz

    always @(posedge clk) begin
        if (rst) begin
            cycle <= 0;
        end else begin
            cycle <= cycle + 1;
            $display(
                "TRACE C=%0d | PC=%08h | IF/ID{pc=%08h instr=%08h} | ID/EX{pc=%08h opc=%02h rs1=%0d rs2=%0d rd=%0d} | FWD{A=%02b B=%02b} | stall=%0b flush=%0b",
                cycle + 1,
                dut.pc_q,
                dut.if_id_pc_q, dut.if_id_instr_q,
                dut.id_ex_pc_q, dut.id_ex_opcode_q, dut.id_ex_rs1_q, dut.id_ex_rs2_q, dut.id_ex_rd_q,
                dut.fwd_a, dut.fwd_b,
                dut.load_use_stall, dut.ex_taken
            );
        end
    end

    initial begin
        $dumpfile("sim/pp_top.vcd");
        $dumpvars(0, tb_pp_top);
        err = 0;
        cycle = 0;

        // reset
        #40;
        rst = 0;
        $display("---- Pipeline Trace Start ----");
        $display("Format: CYCLE | PC | IF/ID | ID/EX | Forwarding | stall | flush");

        // run enough cycles for all instructions to retire
        #600;

        // Register checks
        if (dut.u_rf.regs[1]  !== 32'h0000_0005) begin $display("FAIL x1  = %h", dut.u_rf.regs[1]);  err = err + 1; end
        if (dut.u_rf.regs[2]  !== 32'h0000_0007) begin $display("FAIL x2  = %h", dut.u_rf.regs[2]);  err = err + 1; end
        if (dut.u_rf.regs[3]  !== 32'h0000_000c) begin $display("FAIL x3  = %h", dut.u_rf.regs[3]);  err = err + 1; end
        if (dut.u_rf.regs[4]  !== 32'h0000_0011) begin $display("FAIL x4  = %h", dut.u_rf.regs[4]);  err = err + 1; end
        if (dut.u_rf.regs[5]  !== 32'h1234_5000) begin $display("FAIL x5  = %h", dut.u_rf.regs[5]);  err = err + 1; end
        if (dut.u_rf.regs[6]  !== 32'h1234_5005) begin $display("FAIL x6  = %h", dut.u_rf.regs[6]);  err = err + 1; end
        if (dut.u_rf.regs[7]  !== 32'h1234_5005) begin $display("FAIL x7  = %h", dut.u_rf.regs[7]);  err = err + 1; end
        if (dut.u_rf.regs[8]  !== 32'h1234_500a) begin $display("FAIL x8  = %h", dut.u_rf.regs[8]);  err = err + 1; end
        if (dut.u_rf.regs[9]  !== 32'h0000_0024) begin $display("FAIL x9  = %h", dut.u_rf.regs[9]);  err = err + 1; end
        if (dut.u_rf.regs[10] !== 32'h0000_0029) begin $display("FAIL x10 = %h", dut.u_rf.regs[10]); err = err + 1; end

        // Data memory check at address 0 (little-endian)
        if ({dut.u_dmem.mem[3], dut.u_dmem.mem[2], dut.u_dmem.mem[1], dut.u_dmem.mem[0]} !== 32'h1234_5005) begin
            $display("FAIL mem[0] = %h", {dut.u_dmem.mem[3], dut.u_dmem.mem[2], dut.u_dmem.mem[1], dut.u_dmem.mem[0]});
            err = err + 1;
        end

        if (err == 0)
            $display("PASS: pipeline + forwarding + load-use stall checks");
        else
            $display("FAIL: %0d checks failed", err);

        $finish;
    end
endmodule

