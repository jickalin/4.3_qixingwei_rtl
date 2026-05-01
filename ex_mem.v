`include "risc-v_defines.vh"

module ex_mem (
    input   wire            clk,
    input   wire            rst_n,
    
    input   wire            flush,
    input   wire            stall,
    //frome id_ex
    //to mem
    input   wire            ex_mem_write_en,
    input   wire            ex_mem_read_en,
    input   wire    [2:0]   ex_mem_width,
    
    //wb
    input   wire    [4:0]   ex_rd_addr,
    input   wire            ex_reg_write_en,
    input   wire            ex_wb_sel,
    input   wire            ex_fence,

    input   wire    [31:0]  ex_pc,
    
    //forme ex
    input   wire    [31:0]  ex_alu_result,//store addr or write reg data
   
    
    // to mem
    output  reg             mem_mem_write_en,
    output  reg             mem_mem_read_en,
    output  reg     [2:0]   mem_mem_width,
    output  reg     [31:0]  mem_alu_result, //also to wb
    
    //to mem_wb
    output  reg     [4:0]   mem_rd_addr,
    output  reg             mem_reg_write_en,
    output  reg             mem_wb_sel,
    output  reg             mem_fence,
    // to ex
    output  wire    [31:0]  mem_forward_data,

    output  reg     [31:0]  mem_pc
    );
    
    assign  mem_forward_data    = mem_alu_result;
    always @(posedge clk ) begin
        if (!rst_n) begin
            mem_mem_write_en    <= 1'b0;
            mem_mem_read_en     <= 1'b0;
            mem_mem_width           <= 3'b0;
            mem_alu_result      <= 32'b0;
           
            mem_rd_addr         <= 5'b0;
            mem_reg_write_en    <= 1'b0;
            mem_wb_sel          <= 1'b0;
            mem_fence           <= 1'b0;
            mem_pc              <= 32'b0;

        end 
        else if (flush) begin
            mem_mem_write_en    <= 1'b0;
            mem_mem_read_en     <= 1'b0;
            mem_mem_width       <= 3'b0;
            mem_alu_result      <= 32'b0;
            
            mem_rd_addr         <= 5'b0;
            mem_reg_write_en    <= 1'b0;
            mem_wb_sel          <= 1'b0;
            mem_fence           <= 1'b1;
            mem_pc              <= 32'b0;
        end 
        else if (!stall) begin
            mem_mem_write_en    <= ex_mem_write_en;
            mem_mem_read_en     <= ex_mem_read_en;
            mem_mem_width       <= ex_mem_width;
            mem_alu_result      <= ex_alu_result;
            
            mem_rd_addr         <= ex_rd_addr;
            mem_reg_write_en    <= ex_reg_write_en;
            mem_wb_sel          <= ex_wb_sel;
            mem_fence           <= ex_fence;
            mem_pc              <= ex_pc;
        end
        // else if (stall) begin 
        //      (implicit hold)
        // end
    end

endmodule
