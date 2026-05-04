`include "risc-v_defines.vh"

module id_stage (
    input   wire    [31:0]  instr_i,
    input   wire            inst_valid,
    input   wire    [31:0]  inst_pc,
    output  wire    [4:0]   rs1_addr,          
    output  wire    [4:0]   rs2_addr,
    input   wire    [31:0]  rs1_data,
    input   wire    [31:0]  rs2_data,
   
    output  reg     [3:0]   alu_op,           
    output  wire    [31:0]  alu_in_rs1,   
    output  wire    [31:0]  alu_in_rs2,
    output  reg     [31:0]  imm_ext,
    output  reg     [1:0]   alu_a_sel,
    output  reg     [1:0]   alu_b_sel,
    output  wire            rs1_use,
    output  wire            rs2_use,
    output  reg             jump_r,
    output  reg             branch_en,

    output  reg             mem_read_en,
    output  reg             mem_write_en,
    output  wire    [2:0]   mem_width,
  
    output  reg             jump_en,
    output  wire    [31:0]  pc_jump,
    output  reg             ebreak_en,
    output  reg             ecall_en,
    output  reg             fence_en,
    output  reg             illegal_instr,
    output  wire    [4:0]   rd_addr,          
    output  reg             reg_write_en,
    output  reg             wb_sel,

    input   wire            load_stall,
    output  wire    [1:0]   id_branch_type
);
   
    // 基础解码
    wire [6:0] opcode = instr_i[6:0];
    wire [2:0] funct3 = instr_i[14:12];
    wire [6:0] funct7 = instr_i[31:25];
    assign rs1_addr  = instr_i[19:15];
    assign rs2_addr  = instr_i[24:20];
    assign rd_addr   = instr_i[11:7];
    assign mem_width = funct3; 

    // 1. 立即数生成优化 (直接在 case 中构造，减少中间变量)
    always @(*) begin
        case (opcode)
            `OP_LUI, `OP_AUIPC: imm_ext = {instr_i[31:12], 12'b0};
            `OP_JAL:            imm_ext = {{12{instr_i[31]}}, instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0};
            `OP_BRANCH:         imm_ext = {{20{instr_i[31]}}, instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0};
            `OP_STORE:          imm_ext = {{21{instr_i[31]}}, instr_i[30:25], instr_i[11:7]};
            default:            imm_ext = {{21{instr_i[31]}}, instr_i[30:20]}; // I-type, Load, JALR
        endcase
    end

    // 2. 控制信号组合译码 (将 alu_op 的通用部分提取)
    always @(*) begin
        // 默认值
        reg_write_en  = 0; alu_a_sel = 0; alu_b_sel = 0;
        mem_read_en   = 0; mem_write_en = 0;
        branch_en     = 0; jump_en = 0; jump_r = 0;
        ebreak_en     = 0; ecall_en = 0; fence_en = 0;
        illegal_instr = 0; wb_sel = 0;
        alu_op        = `ALU_ADD;

        case (opcode)
            `OP_LUI:   begin reg_write_en = 1; alu_a_sel = 2; alu_b_sel = 1; end
            `OP_AUIPC: begin reg_write_en = 1; alu_a_sel = 1; alu_b_sel = 1; end
            `OP_JAL:   begin reg_write_en = 1; alu_a_sel = 1; alu_b_sel = 2; jump_en = 1; end
            `OP_JALR:  begin reg_write_en = 1; alu_a_sel = 1; alu_b_sel = 2; jump_r  = 1; end
            `OP_LOAD:  begin reg_write_en = 1; alu_b_sel = 1; mem_read_en = 1; wb_sel = 1; end
            `OP_STORE: begin alu_b_sel = 1; mem_write_en = 1; end
            `OP_BRANCH:begin branch_en = 1; 
                case(funct3)
                    3'b000, 3'b001: alu_op = `ALU_SUB;
                    3'b100, 3'b101: alu_op = `ALU_SLT;
                    3'b110, 3'b111: alu_op = `ALU_SLTU;
                endcase
            end
            `OP_ARITH_I, `OP_ARITH_R: begin
                reg_write_en = 1;
                if (opcode == `OP_ARITH_I) alu_b_sel = 1;
                case (funct3)
                    3'b000: alu_op = (opcode == `OP_ARITH_R && funct7[5]) ? `ALU_SUB : `ALU_ADD;
                    3'b001: alu_op = `ALU_SLL;
                    3'b010: alu_op = `ALU_SLT;
                    3'b011: alu_op = `ALU_SLTU;
                    3'b100: alu_op = `ALU_XOR;
                    3'b101: alu_op = (funct7[5]) ? `ALU_SRA : `ALU_SRL;
                    3'b110: alu_op = `ALU_OR;
                    3'b111: alu_op = `ALU_AND;
                endcase
            end
            7'b0001111: fence_en = 1;
            7'b1110011: if (instr_i[20]) ebreak_en = 1; else ecall_en = 1;
            default:    illegal_instr = 1;
        endcase
    end

    // 3. 跳转地址计算优化 (减少加法器开销)
    // 预选加法器操作数，缩短到 pc_jump 的路径
    wire [31:0] adder_op2 = (jump_en) ? imm_ext : 32'd4;
    assign pc_jump = inst_pc + adder_op2;

    // 4. 辅助信号简化
    assign alu_in_rs1 = rs1_data;
    assign alu_in_rs2 = rs2_data;
    
    // 简化 rs_use 判断逻辑
    assign rs1_use = (opcode != `OP_LUI && opcode != `OP_AUIPC && opcode != `OP_JAL);
    assign rs2_use = (opcode == `OP_ARITH_R || opcode == `OP_BRANCH || opcode == `OP_STORE);

    // 5. 分支类别判断优化
    wire rd_is_link  = (rd_addr  == 5'd1 || rd_addr  == 5'd5);
    wire rs1_is_link = (rs1_addr == 5'd1 || rs1_addr == 5'd5);

    wire is_call = (jump_en || jump_r) && rd_is_link;
    wire is_ret  = jump_r && rs1_is_link && !rd_is_link;
    wire is_jmp_exchange = jump_r && rd_is_link && rs1_is_link && (rd_addr != rs1_addr);

    assign id_branch_type = (branch_en)          ? 2'b00 :
                            (is_call || is_jmp_exchange) ? 2'b01 :
                            (is_ret)             ? 2'b10 : 2'b00;

endmodule
