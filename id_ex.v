module id_ex (
    input   wire            clk,
    input   wire            rst_n,
    input   wire            stall, 
    input   wire            global_stall,
    input   wire            flush,  
    //  From IF/ID 
    input   wire    [31:0]  id_pc,
    input   wire    [31:0]  id_inst,
    input   wire            id_valid,

    //  From ID Decode 
    input   wire    [4:0]   id_rd_addr,
    input   wire            id_reg_write_en,
    input   wire            id_wb_sel,       //  0-ALU, 1-Mem
    
    input   wire    [4:0]   id_rs1_addr,     // (Forwarding)
    input   wire    [4:0]   id_rs2_addr,
    input   wire    [31:0]  id_rs2_data,     

    input   wire    [3:0]   alu_op,
    input   wire    [31:0]  alu_in_a,
    input   wire    [31:0]  alu_in_b,
    input   wire    [1:0]   sign_ab,
    input   wire            id_rs1_use,
    input   wire            id_rs2_use,

    input   wire            id_mem_read_en,
    input   wire            id_mem_write_en,
    input   wire    [2:0]   id_mem_width,   
    input   wire            id_branch_en,

    //  To EX Stage 
    output  reg     [3:0]   ex_alu_op,
    output  reg     [31:0]  ex_alu_in_a,
    output  reg     [31:0]  ex_alu_in_b,
    output  reg     [1:0]   ex_sign_ab,
    output  wire    [2:0]   ex_funct3,
    output  reg             ex_branch_en,

    output  reg     [4:0]   ex_rs1_addr,     // Forwarding/hazard Unit
    output  reg     [4:0]   ex_rs2_addr,
    output  reg             ex_rs1_use,
    output  reg             ex_rs2_use,
    // EX/MEM & MEM/WB 
    output  reg     [4:0]   o_rd_addr,//to hazard and ex_mem
    output  reg     [31:0]  o_rs2_data, // MEM Store data
    output  reg             o_mem_read_en,
    output  reg             o_mem_write_en,//to hazard also
    output  reg     [2:0]   o_mem_width,
    //delivery 
    output  reg     [31:0]  o_id_pc,
    output  reg     [31:0]  o_id_inst,
    output  reg             o_id_valid,
    //wb
    output  reg             o_reg_write_en,
    output  reg             o_wb_sel,
    //hazard 
    output  wire            branch_pc
);
    assign  ex_funct3 = o_id_inst[14:12];
    assign  branch_pc = o_id_pc + 
        {{20{o_id_inst[31]}}, o_id_inst[7], o_id_inst[30:25], o_id_inst[11:8], 1'b0};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_alu_op       <= 4'b0;
            ex_alu_in_a     <= 32'b0;
            ex_alu_in_b     <= 32'b0;
            ex_sign_ab      <= 2'b0;
            ex_branch_en    <= 1'b0;
            ex_rs1_addr     <= 5'b0;
            ex_rs2_addr     <= 5'b0;
            ex_rs1_use      <= 1'b0;
            ex_rs2_use      <= 1'b0;
            ex_rs2_data     <= 32'b0;

            o_mem_read_en   <= 1'b0;
            o_mem_write_en  <= 1'b0;
            o_mem_width     <= 3'b0;
            o_id_pc         <= 32'b0;
            o_id_inst       <= 32'b0;
            o_id_valid      <= 1'b0;
            o_rd_addr       <= 5'b0;
            o_reg_write_en  <= 1'b0;
            o_wb_sel        <= 1'b0;
        end
        else if (flush || stall) begin
            // NOP
            ex_alu_op       <= 4'b0;
            ex_alu_in_a     <= 32'b0;
            ex_alu_in_b     <= 32'b0;
            ex_sign_ab      <= 2'b0;
            ex_branch_en    <= 1'b0;
            ex_rs1_addr     <= 5'b0;
            ex_rs2_addr     <= 5'b0;
            ex_rs1_use      <= 1'b0;
            ex_rs2_use      <= 1'b0;
            ex_rs2_data     <= 32'b0;

            o_mem_read_en   <= 1'b0;
            o_mem_write_en  <= 1'b0;
            o_mem_width     <= 3'b0;
            o_id_pc         <= 32'b0;
            o_id_inst       <= 32'b0;
            o_id_valid      <= 1'b0;
            o_rd_addr       <= 5'b0;
            o_reg_write_en  <= 1'b0;
            o_wb_sel        <= 1'b0;
        end
        else if (!global_stall) begin
            ex_alu_op       <= alu_op;
            ex_alu_in_a     <= alu_in_a;
            ex_alu_in_b     <= alu_in_b;
            ex_sign_ab      <= sign_ab;
            ex_branch_en    <= id_branch_en;
            ex_rs1_addr     <= id_rs1_addr;
            ex_rs2_addr     <= id_rs2_addr;
            ex_rs1_use      <= id_rs1_use;
            ex_rs2_use      <= id_rs2_use;
            ex_rs2_data     <= id_rs2_data;

            o_mem_read_en   <= id_mem_read_en;
            o_mem_write_en  <= id_mem_write_en;
            o_mem_width     <= id_mem_width;
            o_id_pc         <= id_pc;
            o_id_inst       <= id_inst;
            o_id_valid      <= id_valid;
            o_rd_addr       <= id_rd_addr;
            o_reg_write_en  <= id_reg_write_en;
            o_wb_sel        <= id_wb_sel;
        end
        // else (if global_stall) : keep data
    end

endmodule
