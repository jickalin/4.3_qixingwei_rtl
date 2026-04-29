`include "risc-v_defines.vh"


module ex_stage (
    input   wire    [3:0]   ex_alu_op,
    input   wire    [31:0]  ex_alu_rs1,    
    input   wire    [31:0]  ex_alu_rs2,
    input   wire    [31:0]  ex_alu_imm,
    input   wire    [1:0]   ex_a_sel,
    input   wire    [1:0]   ex_b_sel,
    input   wire            ex_rs1_use, 
    input   wire            ex_rs2_use,
    input   wire    [2:0]   ex_funct3,
    input   wire            ex_branch_en,
    input   wire            ex_jump_r,
    input   wire    [31:0]  ex_pc,

    input   wire    [1:0]   mem_forward_en,//[1] a [0] b
    input   wire    [1:0]   wb_forward_en,
    input   wire    [31:0]  mem_forward_data,
    input   wire    [31:0]  wb_forward_data,
    
    output  reg     [31:0]  alu_result_o,
    output  reg     [31:0]  updated_rs2,
    output  wire            branch_taken,
    output  reg     [31:0]  branch_or_jump_pc,

    output  reg     [31:0]  ex_mem_wdata,
    output  wire    [3:0]   ex_be
);
    reg     [31:0]  updated_rs1;
    wire            alu_zero_o;
always @(*) begin
    updated_rs1 = ex_alu_rs1;
    if(ex_rs1_use)begin
    if(mem_forward_en[1])
        updated_rs1 = mem_forward_data;
    else if(wb_forward_en[1])
        updated_rs1 = wb_forward_data;
end
end
always @(*) begin
    updated_rs2 = ex_alu_rs2;
    if(ex_rs2_use) begin
    if(mem_forward_en[0])
        updated_rs2 = mem_forward_data;
    else if(wb_forward_en[0])
        updated_rs2 = wb_forward_data;
end
end

    reg     [31:0]  alu_src1_i;
    reg     [31:0]  alu_src2_i;
    always @(*) begin
        case (ex_a_sel)
            2'b00:   alu_src1_i   = updated_rs1;        
            2'b01:   alu_src1_i   = ex_pc;
            2'b10:   alu_src1_i   = 32'b0;//( LUI : 0 + imm)
            default: alu_src1_i   = updated_rs1;
        endcase
    end

    always @(*) begin
        case (ex_b_sel)
            2'b00:   alu_src2_i   = updated_rs2;
            2'b01:   alu_src2_i   = ex_alu_imm;
            2'b10:   alu_src2_i   = 32'd4; //  JAL/JALR  rd = PC + 4
            default: alu_src2_i   = updated_rs2;
        endcase
    end





    assign alu_zero_o = (alu_result_o == 32'b0);

    always @(*) begin
        case (ex_alu_op)
            `ALU_ADD:  alu_result_o = alu_src1_i + alu_src2_i;
            `ALU_SUB:  alu_result_o = alu_src1_i - alu_src2_i;
            `ALU_AND:  alu_result_o = alu_src1_i & alu_src2_i;
            `ALU_OR:   alu_result_o = alu_src1_i | alu_src2_i;
            `ALU_XOR:  alu_result_o = alu_src1_i ^ alu_src2_i;
            
        
            `ALU_SLL:  alu_result_o = alu_src1_i << alu_src2_i[4:0];
            `ALU_SRL:  alu_result_o = alu_src1_i >> alu_src2_i[4:0];
            `ALU_SRA:  alu_result_o = $signed(alu_src1_i) >>> alu_src2_i[4:0]; 
            
            
            `ALU_SLT:  alu_result_o = ($signed(alu_src1_i) < $signed(alu_src2_i)) ? 32'd1 : 32'd0;//SLT /SGE 
            `ALU_SLTU: alu_result_o = (alu_src1_i < alu_src2_i) ? 32'd1 : 32'd0;
            
            default:   alu_result_o = 32'b0;
        endcase
    end


     assign branch_taken = ex_jump_r ||         //JALR
         ex_branch_en && (
        (ex_funct3 == 3'b000 && alu_zero_o) ||     // BEQ
        (ex_funct3 == 3'b001 && !alu_zero_o) ||    // BNE
        (ex_funct3 == 3'b100 && alu_result_o[0]) ||// BLT
        (ex_funct3 == 3'b101 && !alu_result_o[0]) ||// BGE
        (ex_funct3 == 3'b110 && alu_result_o[0]) ||// BLTU
        (ex_funct3 == 3'b111 && !alu_result_o[0])  // BGEU
        );

    always @(*) begin
    branch_or_jump_pc = 32'b0;
    if(ex_jump_r)
        branch_or_jump_pc = (updated_rs1 + ex_alu_imm) & 32'hFFFFFFFE;
    else if(ex_branch_en)
        branch_or_jump_pc = (ex_pc +ex_alu_imm) & 32'hFFFFFFFE;
    end


      //1T pre to write in mem data
    always @(*) begin
        case (ex_funct3[1:0])
            2'b00: 
                ex_mem_wdata = {4{updated_rs2[7:0]}};
            2'b01: 
                ex_mem_wdata = {2{updated_rs2[15:0]}};
            2'b10: // SW
                ex_mem_wdata = updated_rs2;
            default: 
                ex_mem_wdata = updated_rs2;
        endcase
    end
    wire [1:0] addr_offset = alu_result_o[1:0];
assign ex_be = (ex_funct3[1:0] == 2'b00) ? (4'b0001 << addr_offset) :      // Byte
                     (ex_funct3[1:0] == 2'b01) ? (4'b0011 << {addr_offset[1], 1'b0}) : // Half 
                     (ex_funct3[1:0] == 2'b10) ? 4'b1111 :                       // Word
                                                  4'b0000;

endmodule
