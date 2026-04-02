module pp_top (
    input  wire clk,
    input  wire rst
);
    localparam [31:0] NOP = 32'h0000_0013; // addi x0,x0,0

    // =========================
    // IF stage
    // =========================
    reg  [31:0] pc_q;
    wire [31:0] pc_plus4 = pc_q + 32'd4;
    wire [31:0] if_instr;

    imem #(.DEPTH_WORDS(1024), .MEMFILE("mem/instr_mem.hex")) u_imem (
        .addr(pc_q),
        .rdata(if_instr)
    );

    // IF/ID pipeline reg
    reg [31:0] if_id_pc_q;
    reg [31:0] if_id_instr_q;

    // =========================
    // ID stage
    // =========================
    wire [4:0] id_rs1 = if_id_instr_q[19:15];
    wire [4:0] id_rs2 = if_id_instr_q[24:20];
    wire [4:0] id_rd  = if_id_instr_q[11:7];
    wire [2:0] id_funct3 = if_id_instr_q[14:12];
    wire [6:0] id_funct7 = if_id_instr_q[31:25];
    wire [6:0] id_opcode = if_id_instr_q[6:0];

    wire        id_regwrite, id_memread, id_memwrite, id_memtoreg;
    wire [1:0]  id_aluop;
    wire        id_alusrc, id_branch, id_jump, id_jalr, id_lui, id_auipc;

    controller u_ctrl (
        .instr(if_id_instr_q),
        .regwrite(id_regwrite),
        .memread(id_memread),
        .memwrite(id_memwrite),
        .memtoreg(id_memtoreg),
        .aluop(id_aluop),
        .alusrc(id_alusrc),
        .branch(id_branch),
        .jump(id_jump),
        .jalr(id_jalr),
        .lui(id_lui),
        .auipc(id_auipc)
    );

    wire [31:0] id_imm;
    imm_gen u_imm (
        .instr(if_id_instr_q),
        .imm(id_imm)
    );

    // WB stage -> regfile writeback
    wire        wb_regwrite;
    wire [4:0]  wb_rd;
    wire [31:0] wb_wdata;

    wire [31:0] id_rs1_val, id_rs2_val;
    regfile u_rf (
        .clk(clk),
        .we(wb_regwrite),
        .ra1(id_rs1),
        .ra2(id_rs2),
        .wa(wb_rd),
        .wd(wb_wdata),
        .rd1(id_rs1_val),
        .rd2(id_rs2_val)
    );

    // Simple load-use hazard detection (stall)
    wire id_uses_rs2 = (id_opcode == 7'b0110011) || // R-type
                       (id_opcode == 7'b0100011) || // store
                       (id_opcode == 7'b1100011);   // branch

    // =========================
    // ID/EX pipeline reg
    // =========================
    reg [31:0] id_ex_pc_q;
    reg [31:0] id_ex_rs1_val_q, id_ex_rs2_val_q;
    reg [31:0] id_ex_imm_q;
    reg [4:0]  id_ex_rs1_q, id_ex_rs2_q, id_ex_rd_q;
    reg [2:0]  id_ex_funct3_q;
    reg [6:0]  id_ex_funct7_q;
    reg [6:0]  id_ex_opcode_q;

    reg        id_ex_regwrite_q, id_ex_memread_q, id_ex_memwrite_q, id_ex_memtoreg_q;
    reg [1:0]  id_ex_aluop_q;
    reg        id_ex_alusrc_q, id_ex_branch_q, id_ex_jump_q, id_ex_jalr_q, id_ex_lui_q, id_ex_auipc_q;

    wire load_use_stall = id_ex_memread_q &&
                          (id_ex_rd_q != 5'd0) &&
                          ((id_ex_rd_q == id_rs1) || (id_uses_rs2 && (id_ex_rd_q == id_rs2)));

    // =========================
    // EX stage (with forwarding)
    // =========================
    wire [1:0] fwd_a, fwd_b;

    // EX/MEM signals used for forwarding
    reg        ex_mem_regwrite_q;
    reg [4:0]  ex_mem_rd_q;
    reg [31:0] ex_mem_alu_q;
    reg [31:0] ex_mem_pc4_q;
    reg        ex_mem_memtoreg_q;
    reg        ex_mem_jump_q;
    reg        ex_mem_lui_q;
    reg        ex_mem_auipc_q;
    reg [31:0] ex_mem_imm_q;
    reg [31:0] ex_mem_pc_q;
    reg        ex_mem_memread_q;
    reg        ex_mem_memwrite_q;
    reg [2:0]  ex_mem_funct3_q;
    reg [31:0] ex_mem_rs2_store_q;

    // MEM/WB pipeline regs used for forwarding
    reg        mem_wb_regwrite_q;
    reg [4:0]  mem_wb_rd_q;
    reg [31:0] mem_wb_mem_q;
    reg [31:0] mem_wb_alu_q;
    reg [31:0] mem_wb_pc4_q;
    reg        mem_wb_memtoreg_q;
    reg        mem_wb_jump_q;
    reg        mem_wb_lui_q;
    reg        mem_wb_auipc_q;
    reg [31:0] mem_wb_imm_q;
    reg [31:0] mem_wb_pc_q;

    forwarding_unit u_fwd (
        .id_ex_rs1(id_ex_rs1_q),
        .id_ex_rs2(id_ex_rs2_q),
        .ex_mem_rd(ex_mem_rd_q),
        .ex_mem_regwrite(ex_mem_regwrite_q),
        .mem_wb_rd(mem_wb_rd_q),
        .mem_wb_regwrite(mem_wb_regwrite_q),
        .forward_a(fwd_a),
        .forward_b(fwd_b)
    );

    wire [31:0] wb_result = wb_wdata;

    reg [31:0] ex_op_a_raw, ex_op_b_raw;
    always @(*) begin
        // A operand
        case (fwd_a)
            2'b10: ex_op_a_raw = ex_mem_alu_q;
            2'b01: ex_op_a_raw = wb_result;
            default: ex_op_a_raw = id_ex_rs1_val_q;
        endcase

        // B operand (pre-ALUSrc)
        case (fwd_b)
            2'b10: ex_op_b_raw = ex_mem_alu_q;
            2'b01: ex_op_b_raw = wb_result;
            default: ex_op_b_raw = id_ex_rs2_val_q;
        endcase
    end

    wire [31:0] ex_op_b = id_ex_alusrc_q ? id_ex_imm_q : ex_op_b_raw;

    // ALU control (derived from aluop/funct)
    reg [3:0] ex_alu_ctrl;
    always @(*) begin
        case (id_ex_aluop_q)
            2'b00: ex_alu_ctrl = 4'b0000; // add (addr calc)
            2'b01: ex_alu_ctrl = 4'b0001; // sub (branch compare)
            2'b10: begin // R-type
                case (id_ex_funct3_q)
                    3'b000: ex_alu_ctrl = (id_ex_funct7_q[5] ? 4'b0001 : 4'b0000); // sub/add
                    3'b111: ex_alu_ctrl = 4'b0010; // and
                    3'b110: ex_alu_ctrl = 4'b0011; // or
                    3'b100: ex_alu_ctrl = 4'b0100; // xor
                    3'b001: ex_alu_ctrl = 4'b0101; // sll
                    3'b101: ex_alu_ctrl = (id_ex_funct7_q[5] ? 4'b0111 : 4'b0110); // sra/srl
                    3'b010: ex_alu_ctrl = 4'b1000; // slt
                    3'b011: ex_alu_ctrl = 4'b1001; // sltu
                    default: ex_alu_ctrl = 4'b0000;
                endcase
            end
            2'b11: begin // I-type ALU
                case (id_ex_funct3_q)
                    3'b000: ex_alu_ctrl = 4'b0000; // addi
                    3'b111: ex_alu_ctrl = 4'b0010; // andi
                    3'b110: ex_alu_ctrl = 4'b0011; // ori
                    3'b100: ex_alu_ctrl = 4'b0100; // xori
                    3'b001: ex_alu_ctrl = 4'b0101; // slli
                    3'b101: ex_alu_ctrl = (id_ex_funct7_q[5] ? 4'b0111 : 4'b0110); // srai/srli
                    3'b010: ex_alu_ctrl = 4'b1000; // slti
                    3'b011: ex_alu_ctrl = 4'b1001; // sltiu
                    default: ex_alu_ctrl = 4'b0000;
                endcase
            end
            default: ex_alu_ctrl = 4'b0000;
        endcase
    end

    wire [31:0] ex_alu_y;
    wire        ex_zero;
    alu u_alu (
        .a(ex_op_a_raw),
        .b(ex_op_b),
        .alu_ctrl(ex_alu_ctrl),
        .y(ex_alu_y),
        .zero(ex_zero)
    );

    // Branch decision in EX stage (use forwarded raw operands)
    wire ex_branch_take;
    branch_comp u_bcmp (
        .a(ex_op_a_raw),
        .b(ex_op_b_raw),
        .funct3(id_ex_funct3_q),
        .take(ex_branch_take)
    );

    wire [31:0] ex_pc4 = id_ex_pc_q + 32'd4;
    wire [31:0] ex_branch_target = id_ex_pc_q + id_ex_imm_q;
    wire [31:0] ex_jal_target    = id_ex_pc_q + id_ex_imm_q;
    wire [31:0] ex_jalr_target   = (ex_op_a_raw + id_ex_imm_q) & ~32'd1;

    wire        ex_taken = (id_ex_branch_q && ex_branch_take) || id_ex_jump_q;
    wire [31:0] ex_target = id_ex_jalr_q ? ex_jalr_target :
                            id_ex_jump_q ? ex_jal_target  :
                                           ex_branch_target;

    // =========================
    // MEM stage
    // =========================
    wire [31:0] mem_rdata;
    dmem #(.DEPTH_WORDS(1024), .MEMFILE("mem/data_mem.hex")) u_dmem (
        .clk(clk),
        .memread(ex_mem_memread_q),
        .memwrite(ex_mem_memwrite_q),
        .funct3(ex_mem_funct3_q),
        .addr(ex_mem_alu_q),
        .wdata(ex_mem_rs2_store_q),
        .rdata(mem_rdata)
    );

    // =========================
    // WB stage
    // =========================
    assign wb_regwrite = mem_wb_regwrite_q;
    assign wb_rd       = mem_wb_rd_q;

    // WB mux: jump -> pc+4; lui -> imm; auipc -> pc+imm; load -> mem; else alu
    wire [31:0] wb_auipc_val = mem_wb_pc_q + mem_wb_imm_q;
    assign wb_wdata =
        mem_wb_jump_q    ? mem_wb_pc4_q :
        mem_wb_lui_q     ? mem_wb_imm_q :
        mem_wb_auipc_q   ? wb_auipc_val :
        mem_wb_memtoreg_q? mem_wb_mem_q :
                           mem_wb_alu_q;

    // =========================
    // Sequential logic: pipeline registers + PC
    // =========================
    always @(posedge clk) begin
        if (rst) begin
            pc_q <= 32'd0;
            if_id_pc_q <= 32'd0;
            if_id_instr_q <= NOP;

            // ID/EX bubble
            id_ex_pc_q <= 32'd0;
            id_ex_rs1_val_q <= 32'd0;
            id_ex_rs2_val_q <= 32'd0;
            id_ex_imm_q <= 32'd0;
            id_ex_rs1_q <= 5'd0;
            id_ex_rs2_q <= 5'd0;
            id_ex_rd_q  <= 5'd0;
            id_ex_funct3_q <= 3'd0;
            id_ex_funct7_q <= 7'd0;
            id_ex_opcode_q <= 7'd0;
            id_ex_regwrite_q <= 1'b0;
            id_ex_memread_q  <= 1'b0;
            id_ex_memwrite_q <= 1'b0;
            id_ex_memtoreg_q <= 1'b0;
            id_ex_aluop_q    <= 2'b00;
            id_ex_alusrc_q   <= 1'b0;
            id_ex_branch_q   <= 1'b0;
            id_ex_jump_q     <= 1'b0;
            id_ex_jalr_q     <= 1'b0;
            id_ex_lui_q      <= 1'b0;
            id_ex_auipc_q    <= 1'b0;

            // EX/MEM
            ex_mem_regwrite_q <= 1'b0;
            ex_mem_rd_q <= 5'd0;
            ex_mem_alu_q <= 32'd0;
            ex_mem_pc4_q <= 32'd0;
            ex_mem_memtoreg_q <= 1'b0;
            ex_mem_jump_q <= 1'b0;
            ex_mem_lui_q <= 1'b0;
            ex_mem_auipc_q <= 1'b0;
            ex_mem_imm_q <= 32'd0;
            ex_mem_pc_q <= 32'd0;
            ex_mem_memread_q <= 1'b0;
            ex_mem_memwrite_q <= 1'b0;
            ex_mem_funct3_q <= 3'd0;
            ex_mem_rs2_store_q <= 32'd0;

            // MEM/WB
            mem_wb_regwrite_q <= 1'b0;
            mem_wb_rd_q <= 5'd0;
            mem_wb_mem_q <= 32'd0;
            mem_wb_alu_q <= 32'd0;
            mem_wb_pc4_q <= 32'd0;
            mem_wb_memtoreg_q <= 1'b0;
            mem_wb_jump_q <= 1'b0;
            mem_wb_lui_q <= 1'b0;
            mem_wb_auipc_q <= 1'b0;
            mem_wb_imm_q <= 32'd0;
            mem_wb_pc_q <= 32'd0;
        end else begin
            // PC update (stall prevents PC advancing)
            if (!load_use_stall) begin
                pc_q <= ex_taken ? ex_target : pc_plus4;
            end

            // IF/ID update: stall freezes; taken flushes with NOP
            if (ex_taken) begin
                if_id_pc_q    <= 32'd0;
                if_id_instr_q <= NOP;
            end else if (!load_use_stall) begin
                if_id_pc_q    <= pc_q;
                if_id_instr_q <= if_instr;
            end

            // ID/EX update: on stall insert bubble; on taken flush insert bubble
            if (ex_taken || load_use_stall) begin
                id_ex_pc_q <= 32'd0;
                id_ex_rs1_val_q <= 32'd0;
                id_ex_rs2_val_q <= 32'd0;
                id_ex_imm_q <= 32'd0;
                id_ex_rs1_q <= 5'd0;
                id_ex_rs2_q <= 5'd0;
                id_ex_rd_q  <= 5'd0;
                id_ex_funct3_q <= 3'd0;
                id_ex_funct7_q <= 7'd0;
                id_ex_opcode_q <= 7'd0;
                id_ex_regwrite_q <= 1'b0;
                id_ex_memread_q  <= 1'b0;
                id_ex_memwrite_q <= 1'b0;
                id_ex_memtoreg_q <= 1'b0;
                id_ex_aluop_q    <= 2'b00;
                id_ex_alusrc_q   <= 1'b0;
                id_ex_branch_q   <= 1'b0;
                id_ex_jump_q     <= 1'b0;
                id_ex_jalr_q     <= 1'b0;
                id_ex_lui_q      <= 1'b0;
                id_ex_auipc_q    <= 1'b0;
            end else begin
                id_ex_pc_q <= if_id_pc_q;
                id_ex_rs1_val_q <= id_rs1_val;
                id_ex_rs2_val_q <= id_rs2_val;
                id_ex_imm_q <= id_imm;
                id_ex_rs1_q <= id_rs1;
                id_ex_rs2_q <= id_rs2;
                id_ex_rd_q  <= id_rd;
                id_ex_funct3_q <= id_funct3;
                id_ex_funct7_q <= id_funct7;
                id_ex_opcode_q <= id_opcode;

                id_ex_regwrite_q <= id_regwrite;
                id_ex_memread_q  <= id_memread;
                id_ex_memwrite_q <= id_memwrite;
                id_ex_memtoreg_q <= id_memtoreg;
                id_ex_aluop_q    <= id_aluop;
                id_ex_alusrc_q   <= id_alusrc;
                id_ex_branch_q   <= id_branch;
                id_ex_jump_q     <= id_jump;
                id_ex_jalr_q     <= id_jalr;
                id_ex_lui_q      <= id_lui;
                id_ex_auipc_q    <= id_auipc;
            end

            // EX/MEM update
            ex_mem_regwrite_q <= id_ex_regwrite_q;
            ex_mem_rd_q       <= id_ex_rd_q;
            ex_mem_alu_q      <= ex_alu_y;
            ex_mem_pc4_q      <= ex_pc4;
            ex_mem_memtoreg_q <= id_ex_memtoreg_q;
            ex_mem_jump_q     <= id_ex_jump_q;
            ex_mem_lui_q      <= id_ex_lui_q;
            ex_mem_auipc_q    <= id_ex_auipc_q;
            ex_mem_imm_q      <= id_ex_imm_q;
            ex_mem_pc_q       <= id_ex_pc_q;
            ex_mem_memread_q  <= id_ex_memread_q;
            ex_mem_memwrite_q <= id_ex_memwrite_q;
            ex_mem_funct3_q   <= id_ex_funct3_q;

            // store data should be forwarded too (use ex_op_b_raw which already forwarded)
            ex_mem_rs2_store_q <= ex_op_b_raw;

            // MEM/WB update
            mem_wb_regwrite_q <= ex_mem_regwrite_q;
            mem_wb_rd_q       <= ex_mem_rd_q;
            mem_wb_mem_q      <= mem_rdata;
            mem_wb_alu_q      <= ex_mem_alu_q;
            mem_wb_pc4_q      <= ex_mem_pc4_q;
            mem_wb_memtoreg_q <= ex_mem_memtoreg_q;
            mem_wb_jump_q     <= ex_mem_jump_q;
            mem_wb_lui_q      <= ex_mem_lui_q;
            mem_wb_auipc_q    <= ex_mem_auipc_q;
            mem_wb_imm_q      <= ex_mem_imm_q;
            mem_wb_pc_q       <= ex_mem_pc_q;
        end
    end
endmodule

