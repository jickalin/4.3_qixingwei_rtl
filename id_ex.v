`include "risc-v_defines.vh"

module id_ex (
    input   wire            clk,
    input   wire            rst_n,
    input   wire            load_stall, 
    input   wire            stall,
    input   wire            flush,  
    //  From IF/ID 
    input   wire    [31:0]  id_pc,
    input   wire    [31:0]  id_inst,
    input   wire            id_valid,

    //  From ID Decode   
    //to ex
    input   wire    [3:0]   id_alu_op,
    input   wire    [31:0]  id_alu_rs1,
    input   wire    [31:0]  id_alu_rs2,
    input   wire    [31:0]  id_imm_ext,
    input   wire    [1:0]   id_a_sel,
    input   wire    [1:0]   id_b_sel,
    input   wire            id_rs1_use,
    input   wire            id_rs2_use,
    input   wire            id_branch_en,
    input   wire            id_jump_r,

    // to mem
    input   wire            id_mem_read_en,
    input   wire            id_mem_write_en,
    input   wire    [2:0]   id_mem_width,

    // to wb
    input   wire    [4:0]   id_rd_addr,
    input   wire            id_reg_write_en,
    input   wire            id_wb_sel,       //  0-ALU, 1-Mem
    input   wire            id_fence,
    // to forward
    input   wire    [4:0]   id_rs1_addr,     
    input   wire    [4:0]   id_rs2_addr,   

    //  To EX Stage 
    output  reg     [3:0]   ex_alu_op,
    output  reg     [31:0]  ex_alu_rs1,//a
    output  reg     [31:0]  ex_alu_rs2,//b also to ex_mem
    output  reg     [31:0]  ex_alu_imm,
    output  reg     [1:0]   ex_a_sel,
    output  reg     [1:0]   ex_b_sel,
    output  reg             ex_rs1_use,//also to forward hazard 
    output  reg             ex_rs2_use,
    output  wire    [2:0]   ex_funct3,//also to ex_mem sign byte hw word
    output  reg             ex_branch_en,
    output  reg             ex_jump_r,
    //
    output  reg     [4:0]   ex_rs1_addr,     // Forwarding/hazard Unit
    output  reg     [4:0]   ex_rs2_addr,
    // to ex_mem 
    output  reg             ex_mem_read_en,
    output  reg             ex_mem_write_en,
    output  reg     [2:0]   ex_mem_width,

    output  reg             ex_fence,
    //delivery to ex_mem 
    output  reg     [31:0]  ex_pc,//to ex also
    output  reg     [31:0]  ex_inst,
    output  reg             ex_valid,
    //wb
    output  reg     [4:0]   ex_rd_addr,
    output  reg             ex_reg_write_en,
    output  reg             ex_wb_sel
    
);
    assign  ex_funct3 = ex_inst[14:12];
    always @(posedge clk ) begin
        if (!rst_n) begin
            ex_alu_op       <= 4'b0;
            ex_alu_rs1      <= 32'b0;
            ex_alu_rs2      <= 32'b0;
            ex_alu_imm      <= 32'b0;
            ex_a_sel        <= 2'b0;
            ex_b_sel        <= 2'b0;
            ex_rs1_use      <= 1'b0;
            ex_rs2_use      <= 1'b0;
            ex_branch_en    <= 1'b0;
            ex_jump_r       <= 1'b0;
            ex_rs1_addr     <= 5'b0;
            ex_rs2_addr     <= 5'b0;
            ex_rd_addr      <= 5'b0;

            ex_mem_read_en   <= 1'b0;
            ex_mem_write_en  <= 1'b0;
            ex_mem_width     <= 3'b0;
            ex_fence         <= 1'b0;
            ex_pc         <= 32'b0;
            ex_inst       <= 32'b0;
            ex_valid      <= 1'b0;
            ex_reg_write_en  <= 1'b0;
            ex_wb_sel        <= 1'b0;
        end
        else if (flush || load_stall) begin
            ex_alu_op       <= `ALU_ADD;
            ex_alu_rs1      <= 32'b0;
            ex_alu_rs2      <= 32'b0;
            ex_alu_imm      <= 32'b0;
            ex_a_sel        <= 2'b0;
            ex_b_sel        <= 2'b0;
            ex_rs1_use      <= 1'b0;
            ex_rs2_use      <= 1'b0;
            ex_branch_en    <= 1'b0;
            ex_jump_r       <= 1'b0;
            ex_rs1_addr     <= 5'b0;
            ex_rs2_addr     <= 5'b0;
            ex_rd_addr      <= 5'b0;

            ex_mem_read_en  <= 1'b0;
            ex_mem_write_en <= 1'b0;
            ex_mem_width    <= 3'b0;
            ex_fence        <= 1'b0;
            ex_pc           <= 32'b0;
            ex_inst         <= 32'b0;
            ex_valid        <= 1'b0;
            ex_reg_write_en  <= 1'b0;
            ex_wb_sel        <= 1'b0;
    
        end
        else if (!stall) begin
            ex_alu_op       <= id_alu_op;
            ex_alu_rs1      <= id_alu_rs1;
            ex_alu_rs2      <= id_alu_rs2;
            ex_alu_imm      <= id_imm_ext;
            ex_a_sel        <= id_a_sel;
            ex_b_sel        <= id_b_sel;
            ex_rs1_use      <= id_rs1_use;
            ex_rs2_use      <= id_rs2_use;
            ex_branch_en    <= id_branch_en;
            ex_jump_r       <= id_jump_r;
            ex_rs1_addr     <= id_rs1_addr;
            ex_rs2_addr     <= id_rs2_addr;
            ex_rd_addr      <= id_rd_addr;

            ex_mem_read_en   <= id_mem_read_en;
            ex_mem_write_en  <= id_mem_write_en;
            ex_mem_width     <= id_mem_width;
            ex_fence        <= id_fence;
            ex_pc         <= id_pc;
            ex_inst       <= id_inst;
            ex_valid      <= id_valid;
            ex_reg_write_en  <= id_reg_write_en;
            ex_wb_sel        <= id_wb_sel;
        end
        // else (if global_stall) : keep data
    end

endmodule
