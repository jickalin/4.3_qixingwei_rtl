module mem_wb (
    input   wire            clk,
    input   wire            rst_n,
    input   wire    [31:0]  mem_pc,

    input   wire            stall,
    input   wire            flush,

    input   wire     [4:0]  mem_rd_addr,
    input   wire            mem_reg_write_en,
    input   wire            mem_wb_sel,
    input   wire            mem_fence,
    input   wire    [31:0]  mem_alu_result,
    input   wire    [31:0]  mem_load_data,

    output  wire    [31:0]  wb_data,
    output  reg     [4:0]   wb_addr,
    output  reg             wb_en,
    output  reg     [31:0]  wb_pc,
    output  reg             wb_fence

   );
   
reg     [31:0]  wb_alu_result;
reg     [31:0]  wb_load_data;
reg             wb_sel;
    assign wb_data = wb_sel ?   wb_load_data : wb_alu_result;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin

        wb_addr         <= 0;
        wb_en           <= 0;
        wb_alu_result   <= 0;
        wb_load_data    <= 0;
        wb_pc           <= 0;
        wb_sel          <= 0;
        wb_fence        <= 0;
    end else if(flush) begin
        wb_addr         <= 0;
        wb_en           <= 0;
        wb_alu_result   <= 0;
        wb_load_data    <= 0;
        wb_pc           <= 0;
        wb_sel          <= 0;
        wb_fence        <= 0;
    end else if(!stall) begin
        wb_addr         <= mem_rd_addr;
        wb_en           <= mem_reg_write_en;
        wb_alu_result   <= mem_alu_result;
        wb_load_data    <= mem_load_data; 
        wb_pc           <= mem_pc;
        wb_sel          <= mem_wb_sel;
        wb_fence        <= mem_fence;

    end
end
   endmodule

