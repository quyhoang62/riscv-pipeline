module imem #(
    parameter DEPTH_WORDS = 1024,
    parameter MEMFILE     = "mem/instr_mem.hex"
) (
    input  wire [31:0] addr,
    output wire [31:0] rdata
);
    reg [31:0] mem [0:DEPTH_WORDS-1];
    integer i;
    integer fd;
    integer code;
    integer idx;
    reg [31:0] word_buf;

    initial begin
        for (i = 0; i < DEPTH_WORDS; i = i + 1)
            mem[i] = 32'h0000_0013;

        fd = $fopen(MEMFILE, "r");
        if (fd != 0) begin
            idx = 0;
            while (!$feof(fd) && (idx < DEPTH_WORDS)) begin
                code = $fscanf(fd, "%h\n", word_buf);
                if (code == 1) begin
                    mem[idx] = word_buf;
                    idx = idx + 1;
                end else begin
                    code = $fgetc(fd);
                end
            end
            $fclose(fd);
        end
    end

    assign rdata = mem[addr[31:2]];
endmodule

