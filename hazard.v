module hazard (
    //load ues
    input   wire    [4:0]       id_ex_rd,
    input                       id_ex_mem_read, 
    input   wire    [4:0]       if_id_rs1,
    input   wire    [4:0]       if_id_rs2,

    output  reg                 load_stall,
    output  reg                 global_stall,
    output  wire                flush,


    input   wire                jump_en,
    input   wire    [31:0]      jump_pc,
    input   wire                branch_taken,
    input   wire    [31:0]      branch_pc,

    output  reg                 jump_to_if,
    output  reg     [31:0]      jump_pc_if
);
    always @(*) begin// Load-Use 
        stall = 1'b0;
        if (id_ex_mem_read && (id_ex_rd != 5'd0) 
           ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2))) begin
            load_stall = 1'b1; 
        end
    end

    always@(*) begin //jump or branch
        jump_to_if  = 0;
        jump_pc_if  = 0;
        if(branch_taken)begin
            jump_to_if = 1;
            jump_pc_if = branch_pc;
        end else if(jump_en) begin
            jump_to_if = 1;
            jump_pc_if = jump_pc;
        end
    end

assign flush = jump_to_if;
assign global_stall = 0;

endmodule
