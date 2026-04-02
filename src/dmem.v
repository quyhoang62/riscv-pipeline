module dmem #(
    parameter DEPTH_WORDS = 1024,
    parameter MEMFILE     = "mem/data_mem.hex"
) (
    input  wire        clk,
    input  wire        memread,
    input  wire        memwrite,
    input  wire [2:0]  funct3,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata
);
    reg [7:0] mem [0:(DEPTH_WORDS*4)-1];

    integer i;
    initial begin
        for (i = 0; i < (DEPTH_WORDS*4); i = i + 1)
            mem[i] = 8'd0;
        $readmemh(MEMFILE, mem);
    end

    wire [31:0] a = addr;
    wire [31:0] word =
        {mem[{a[31:2],2'b11}], mem[{a[31:2],2'b10}], mem[{a[31:2],2'b01}], mem[{a[31:2],2'b00}]};

    always @(*) begin
        rdata = 32'd0;
        if (memread) begin
            case (funct3)
                3'b000: rdata = {{24{word[7]}},  word[7:0]};   // lb
                3'b100: rdata = {24'd0,          word[7:0]};   // lbu
                3'b001: rdata = {{16{word[15]}}, word[15:0]};  // lh
                3'b101: rdata = {16'd0,          word[15:0]};  // lhu
                3'b010: rdata = word;                          // lw
                default: rdata = word;
            endcase
        end
    end

    always @(posedge clk) begin
        if (memwrite) begin
            case (funct3)
                3'b000: begin // sb
                    mem[{a[31:2],2'b00}] <= wdata[7:0];
                end
                3'b001: begin // sh
                    mem[{a[31:2],2'b00}] <= wdata[7:0];
                    mem[{a[31:2],2'b01}] <= wdata[15:8];
                end
                3'b010: begin // sw
                    mem[{a[31:2],2'b00}] <= wdata[7:0];
                    mem[{a[31:2],2'b01}] <= wdata[15:8];
                    mem[{a[31:2],2'b10}] <= wdata[23:16];
                    mem[{a[31:2],2'b11}] <= wdata[31:24];
                end
                default: begin end
            endcase
        end
    end
endmodule

