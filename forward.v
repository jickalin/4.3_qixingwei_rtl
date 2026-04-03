module forward (
    input   wire    [4:0]   for_id_rs1, 
    input   wire    [4:0]   for_id_rs2,
    input                   for_rs1_use,
    input   wire            for_rs2_use,
    input   wire    [4:0]   for_mem_rd,
    input   wire    [4:0]   for_wb_rd, 
    input   wire            for_mem_reg_write, for_wb_reg_write, 

    output  reg     [1:0]   mem_forward_en,//[1] rs1 [0] rs2
    output  reg     [1:0]   wb_forward_en 
);

    always @ (*) begin
        mem_forward_en[1]   = 0;
        wb_forward_en[1]    = 0;
    if(for_rs1_use && for_mem_reg_write && (for_mem_rd != 5'd0) && (for_id_rs1 == for_mem_rd))
        mem_forward_en[1]   = 1;
    else if(for_rs1_use && for_wb_reg_write && (for_wb_rd != 5'd0) && (for_id_rs1 == for_wb_rd))
        wb_forward_en[1]    = 1;
    end
    always @ (*) begin
        mem_forward_en[0]   = 0;
        wb_forward_en[0]    = 0;
    if(for_rs2_use && for_mem_reg_write && (for_mem_rd != 5'd0) && (for_id_rs2 == for_mem_rd))
        mem_forward_en[0]   = 1;
    else if(for_rs2_use && for_wb_reg_write && (for_wb_rd != 5'd0) && (for_id_rs2 == for_wb_rd))
        wb_forward_en[0]    = 1;
    end
    endmodule






