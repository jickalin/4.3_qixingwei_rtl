`include "risc-v_defines.vh"


module ex_stage (
    input   wire    [31:0]  alu_src_a,    
    input   wire    [31:0]  alu_src_b, 
    input   wire    [1:0]   sign_ab,
    input   wire    [3:0]   decoder2alu_sel,
    input   wire    [2:0]   ex_funct3,
    input   wire            branch_en,
    input   wire    [1:0]   mem_forward_en,//[1] a [0] b
    input   wire    [1:0]   wb_forward_en,
    input   wire    [31:0]  mem_forward_data,
    input   wire    [31:0]  wb_forward_data,
    
    output  reg     [31:0]  alu_result_o,  
    output  wire            alu_zero_o,
    output  wire            branch_taken
);

    reg     [31:0]  alu_src1_i;
    reg     [31:0]  alu_src2_i;

always @(*) begin
    alu_src1_i = alu_src_a;
    if(sign_ab[1])begin
    if(mem_forward_en[1])
        alu_src1_i = mem_forward_data;
    else if(wb_forward_en[1])
        alu_src1_i = wb_forward_data;
end
end
always @(*) begin
    alu_src2_i = alu_src_b;
    if(sign_ab[0]) begin
    if(mem_forward_en[0])
        alu_src2_i = mem_forward_data;
    else if(wb_forward_en[0])
        alu_src2_i = wb_forward_data;
end
end


    assign alu_zero_o = (alu_result_o == 32'b0);

    always @(*) begin
        case (decoder2alu_sel)
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


     assign branch_taken = branch_en && (
        (ex_funct3 == 3'b000 && alu_zero_o) ||     // BEQ
        (ex_funct3 == 3'b001 && !alu_zero_o) ||    // BNE
        (ex_funct3 == 3'b100 && alu_result_o[0]) ||// BLT
        (ex_funct3 == 3'b101 && !alu_result_o[0]) ||// BGE
        (ex_funct3 == 3'b110 && alu_result_o[0]) ||// BLTU
        (ex_funct3 == 3'b111 && !alu_result_o[0])  // BGEU
        );



endmodule
