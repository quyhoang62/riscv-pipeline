`timescale 1ns/1ps

module tb_reset_basic;
    reg clk = 0;
    reg rst = 1;
    integer err;

    pp_top dut (
        .clk(clk),
        .rst(rst)
    );

    always #5 clk = ~clk;

    function has_x32;
        input [31:0] v;
        begin
            has_x32 = (^v === 1'bx);
        end
    endfunction

    initial begin
        $dumpfile("sim/tb_reset_basic.vcd");
        $dumpvars(0, tb_reset_basic);
        err = 0;

        // Allow one edge so reset values are registered into pipeline flops.
        @(posedge clk);
        #1;

        // Keep reset asserted for a few cycles and verify pipeline init state.
        repeat (4) begin
            @(posedge clk);
            #1;
            if (dut.pc_q !== 32'd0) begin $display("FAIL pc_q during reset = %h", dut.pc_q); err = err + 1; end
            if (dut.if_id_pc_q !== 32'd0) begin $display("FAIL if_id_pc_q during reset = %h", dut.if_id_pc_q); err = err + 1; end
            if (dut.if_id_instr_q !== 32'h0000_0013) begin $display("FAIL if_id_instr_q during reset = %h", dut.if_id_instr_q); err = err + 1; end
            if (dut.id_ex_regwrite_q !== 1'b0) begin $display("FAIL id_ex_regwrite_q during reset"); err = err + 1; end
            if (dut.ex_mem_regwrite_q !== 1'b0) begin $display("FAIL ex_mem_regwrite_q during reset"); err = err + 1; end
            if (dut.ex_mem_memwrite_q !== 1'b0) begin $display("FAIL ex_mem_memwrite_q during reset"); err = err + 1; end
            if (dut.mem_wb_regwrite_q !== 1'b0) begin $display("FAIL mem_wb_regwrite_q during reset"); err = err + 1; end
        end

        rst = 0;
        repeat (3) @(posedge clk);
    #1;

        if (dut.load_use_stall !== 1'b0) begin $display("FAIL stall after reset = %b", dut.load_use_stall); err = err + 1; end
        if (dut.ex_taken !== 1'b0) begin $display("FAIL flush(ex_taken) after reset = %b", dut.ex_taken); err = err + 1; end

        if (has_x32(dut.pc_q)) begin $display("FAIL pc_q has X"); err = err + 1; end
        if (has_x32(dut.if_id_pc_q)) begin $display("FAIL if_id_pc_q has X"); err = err + 1; end
        if (has_x32(dut.if_id_instr_q)) begin $display("FAIL if_id_instr_q has X"); err = err + 1; end
        if (has_x32(dut.id_ex_pc_q)) begin $display("FAIL id_ex_pc_q has X"); err = err + 1; end
        if (has_x32(dut.ex_mem_alu_q)) begin $display("FAIL ex_mem_alu_q has X"); err = err + 1; end
        if (has_x32(dut.mem_wb_alu_q)) begin $display("FAIL mem_wb_alu_q has X"); err = err + 1; end

        if (err == 0)
            $display("PASS: tb_reset_basic");
        else
            $display("FAIL: tb_reset_basic (%0d errors)", err);

        $finish;
    end
endmodule
