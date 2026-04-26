module hazard (
    input   wire                clk,
    input   wire                rst_n,
    //load ues
    input   wire    [4:0]       id_ex_rd,
    input                       id_ex_mem_read, 
    input   wire    [4:0]       if_id_rs1,
    input   wire    [4:0]       if_id_rs2,//not ues if_id_rs1/rs2 use

    output  reg                 load_stall,
    output  wire                fence_stall,
    output  wire                global_stall,
    output  wire                flush,
    output  wire                flush_ex_jal,
    output  wire                global_flush,


    input   wire                jump_en,
    input   wire    [31:0]      jump_pc,
    input   wire                branch_taken,
    input   wire    [31:0]      branch_pc,
    input   wire                wb_fence,
    input   wire                mem_fence,

    output  reg                 jump_to_if,
    output  reg     [31:0]      jump_pc_if,

    input   wire                mem_ready,
    input   wire                id_ebreak_en,
    input   wire                id_ecall_en,
    input   wire                id_fence_en,
    input   wire                id_illegal_instr

);
    always @(*) begin// Load-Use 
        load_stall = 1'b0;
        if (id_ex_mem_read && (id_ex_rd != 5'd0)) 
          if ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2)) begin
            load_stall = 1'b1; 
        end
    end
wire    fence_jump;

    always@(*) begin //jump or branch
        jump_to_if  = 0;
        jump_pc_if  = 0;
        if(branch_taken)begin
            jump_to_if = 1;
            jump_pc_if = branch_pc;
        end else if(jump_en) begin
            jump_to_if = 1;
            jump_pc_if = jump_pc;
        end else if(fence_jump || load_stall) begin
            jump_to_if = 1;
            jump_pc_if = jump_pc;
        end
    end
reg     mem_fence_reg;

always @ (posedge clk or negedge rst_n)begin
    if(!rst_n) begin
        mem_fence_reg    <= 0;
    end else begin
        mem_fence_reg    <= mem_fence;
    end
end

assign  fence_jump = mem_fence & (!mem_fence_reg);
assign flush = branch_taken || jump_en || id_ebreak_en || id_ecall_en ||id_illegal_instr;
assign flush_ex_jal = branch_taken || id_ebreak_en || id_ecall_en ||id_illegal_instr; //if jal ex is not flush
assign fence_stall = !mem_ready || (id_fence_en && !wb_fence);
assign global_flush = 0; 
assign global_stall = 0;
endmodule
