`timescale 1ns/1ps

module tb_pp_top;
    reg clk = 0;
    reg rst = 1;

    pp_top dut (
        .clk(clk),
        .rst(rst)
    );

    always #5 clk = ~clk; // 100MHz

    initial begin
        // reset
        #40;
        rst = 0;

        // run
        #5000;
        $finish;
    end
endmodule

