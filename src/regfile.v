module regfile (
    input  wire        clk,
    input  wire        we,
    input  wire [4:0]  ra1,
    input  wire [4:0]  ra2,
    input  wire [4:0]  wa,
    input  wire [31:0] wd,
    output wire [31:0] rd1,
    output wire [31:0] rd2
);
    reg [31:0] regs [0:31];

    assign rd1 = (ra1 == 5'd0) ? 32'd0 : regs[ra1];
    assign rd2 = (ra2 == 5'd0) ? 32'd0 : regs[ra2];

    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1)
            regs[i] = 32'd0;
    end

    always @(posedge clk) begin
        if (we && (wa != 5'd0)) begin
            regs[wa] <= wd;
        end
    end
endmodule

