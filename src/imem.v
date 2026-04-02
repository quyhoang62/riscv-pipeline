module imem #(
    parameter DEPTH_WORDS = 1024,
    parameter MEMFILE     = "mem/instr_mem.hex"
) (
    input  wire [31:0] addr,
    output wire [31:0] rdata
);
    reg [31:0] mem [0:DEPTH_WORDS-1];

    initial begin
        $readmemh(MEMFILE, mem);
    end

    assign rdata = mem[addr[31:2]];
endmodule

