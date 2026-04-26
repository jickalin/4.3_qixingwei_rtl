`include "risc-v_defines.vh"

module id_stage (
    input   wire    [31:0]  instr_i, // instruction
    input   wire            inst_valid,
    input   wire    [31:0]  inst_pc,
    // reg_file and  addr also to id_ex
    output  wire    [4:0]   rs1_addr,          
    output  wire    [4:0]   rs2_addr,
    input   wire    [31:0]  rs1_data,
    input   wire    [31:0]  rs2_data,
   
    // ex 
    output  reg     [3:0]   alu_op,           
    output  wire    [31:0]  alu_in_rs1,   
    output  wire    [31:0]  alu_in_rs2,
    output  reg     [31:0]  imm_ext,
    output  reg     [1:0]   alu_a_sel,// ALU A (0:rs1, 1:PC,2:0)
    output  reg     [1:0]   alu_b_sel,// ALU B (0:rs2, 1:imm 2:4)
    output  wire            rs1_use,    // and to hazard
    output  wire            rs2_use,
    output  reg             jump_r,     //jalr
    output  reg             branch_en,  // B-type

    // Data Memory
    output  reg             mem_read_en,      // 
    output  reg             mem_write_en,     // 
    output  wire    [2:0]   mem_width,        // (funct3: LB, LH, LW
  
        //to hazard    
    output  reg             jump_en,     // JAL
    output  wire    [31:0]  pc_jump,
    output  reg              ebreak_en,      // EBREAK
    output  reg              ecall_en,       // ECALL
    output  reg              fence_en,       // FENCE
    output  reg              illegal_instr,
     // reg_wb_delivey
    output  wire    [4:0]   rd_addr,          
    output  reg             reg_write_en,
    output  reg             wb_sel, //write in reg data frome 0:alu 1: mem

    input   wire            load_stall

    );
   
    wire    [6:0]       opcode = instr_i[6:0];
    wire    [2:0]       funct3 = instr_i[14:12];
    wire    [6:0]       funct7 = instr_i[31:25];

    assign  rs1_addr        = instr_i[19:15];
    assign  rs2_addr        = instr_i[24:20];
    assign  rd_addr         = instr_i[11:7];//rd is certain write_en is high can write in
    assign  mem_width       = funct3; 

    // Imm Gen
    always @(*) begin
        case (opcode)
            `OP_LUI,`OP_AUIPC: // U-type (LUI, AUIPC)
                imm_ext = {instr_i[31:12], 12'b0};//onely this is in high

            `OP_JAL:             // J-type (JAL)
                imm_ext = {{12{instr_i[31]}}, instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0};

            `OP_JALR,`OP_LOAD,`OP_ARITH_I: //I JALR, Load, Addi,and SLLI attention shamt is 5bit at low 
                imm_ext = {{20{instr_i[31]}}, instr_i[31:20]};

            `OP_BRANCH:             // B-type (Branch)
                imm_ext = {{20{instr_i[31]}}, instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0};

            `OP_STORE:             // S-type (Store)
                imm_ext = {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};

            default: 
                imm_ext = 32'b0;   
        endcase
    end

    // opcode
    always @(*) begin
        reg_write_en  = 0;
        alu_a_sel     = 0; // default select rs1
        alu_b_sel     = 0; //  rs2
        mem_read_en   = 0;
        mem_write_en  = 0;
        branch_en     = 0;
        jump_en       = 0;
        jump_r        = 0;
        ebreak_en     = 0;
        ecall_en      = 0;
        fence_en      = 0;
        illegal_instr = 0;
        wb_sel        = 0;
        
        case (opcode)
            `OP_LUI  : begin // LUI
                reg_write_en    = 1;
                alu_a_sel       = 2;
                alu_b_sel       = 1; // imm，and ALU imm + 0
            end
            `OP_AUIPC: begin // AUIPC
                reg_write_en    = 1;
                alu_a_sel       = 1; //  PC
                alu_b_sel       = 1; //  imm
            end
            `OP_JAL: begin // JAL
                reg_write_en    = 1;
                alu_a_sel       = 1;
                alu_b_sel       = 2; // pc = pc +4 to rd
                jump_en         = 1;
            end
            `OP_JALR: begin // JALR
                reg_write_en = 1;
                alu_a_sel    = 1;
                alu_b_sel    = 2;//is 4 pc = pc +4 to rd
                jump_r       = 1; 
            end
            `OP_BRANCH: begin // Branch
                branch_en   = 1;//rs1 - rs2 to judge branch or not 
                //jump_src_sel= 0;
            end
            `OP_LOAD : begin // Load
                reg_write_en = 1;
                alu_b_sel   = 1; // rs1 + imm
                mem_read_en = 1;
                wb_sel      = 1;// write in reg ,and data frome mem
            end
            `OP_STORE: begin // Store
                alu_b_sel = 1; //  Compute ADDR：rs1 + imm
                mem_write_en = 1;
                
            end
            `OP_ARITH_I: begin // OP-Imm ADDI
                reg_write_en = 1;
                alu_b_sel = 1;
            end
            `OP_ARITH_R: begin // OP ADDR
                reg_write_en = 1;
            end
            7'b0001111: fence_en = 1;//FENCE FENCE.TSO PAUSH

            7'b1110011: begin
                if (instr_i[20]) ebreak_en = 1;//ERAEAK
                else             ecall_en  = 1;//ECALL
            end
            default: illegal_instr = 1;
        endcase
    end

    // ALU decode
    always @(*) begin
        case (opcode)
            `OP_LUI  : alu_op = `ALU_ADD; // LUI IMM + 0
            `OP_AUIPC: alu_op = `ALU_ADD; // AUIPC (ADD)
            `OP_JAL  : alu_op = `ALU_ADD;//PC + 4
            `OP_JALR : alu_op = `ALU_ADD;//PC + 4

            `OP_BRANCH: begin // Branch (ALU TO compare bigger)
                case (funct3)
                    3'b000, 3'b001: alu_op = `ALU_SUB; // BEQ, BNE (SUB =0?)
                    3'b100, 3'b101: alu_op = `ALU_SLT; // BLT, BGE (SLT)
                    3'b110, 3'b111: alu_op = `ALU_SLTU; // BLTU, BGEU (SLTU)
                    default: alu_op = `ALU_ADD;
                endcase
            end

            `OP_LOAD,`OP_STORE: alu_op = `ALU_ADD; // Load/Store (ADD=rs1 + imm)

            `OP_ARITH_R  : begin // R-type
                case (funct3)
                    3'b000: alu_op = (funct7[5]) ? `ALU_SUB : `ALU_ADD; // SUB : ADD
                    3'b001: alu_op = `ALU_SLL; // SLL
                    3'b010: alu_op = `ALU_SLT; // SLT
                    3'b011: alu_op = `ALU_SLTU; // SLTU
                    3'b100: alu_op = `ALU_XOR; // XOR
                    3'b101: alu_op = (funct7[5]) ? `ALU_SRA : `ALU_SRL; // SRA : SRL
                    3'b110: alu_op = `ALU_OR; // OR
                    3'b111: alu_op = `ALU_AND; // AND
                endcase
            end
            `OP_ARITH_I: begin // I-type (Arithmetic)
                case (funct3)
                    3'b000: alu_op = `ALU_ADD; // ADDI
                    3'b001: alu_op = `ALU_SLL; // SLLI
                    3'b010: alu_op = `ALU_SLT; // SLTI
                    3'b011: alu_op = `ALU_SLTU; // SLTIU
                    3'b100: alu_op = `ALU_XOR; // XORI
                    3'b101: alu_op = (funct7[5]) ? `ALU_SRA : `ALU_SRL; // SRAI : SRLI
                    3'b110: alu_op = `ALU_OR; // ORI
                    3'b111: alu_op = `ALU_AND; // ANDI
                endcase
            end
                        default: alu_op = `ALU_ADD;
        endcase
    end


    assign alu_in_rs1 = rs1_data;
    assign alu_in_rs2 = rs2_data;

    //jump addr
assign pc_jump     = (jump_en)  ? inst_pc   + imm_ext   :
       (fence_en || load_stall) ? inst_pc   + 4         :   0;

//jalr rs1 to jump_pc,pc+4 to rd store
assign rs1_use = (alu_a_sel == 2'b00) || jump_r;
// store alu_b_sel =1 but rs2 is use
assign rs2_use = (alu_b_sel == 2'b00) || mem_write_en ;

endmodule
