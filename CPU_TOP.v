`include "risc-v_defines.vh"
module rv32i_core_top (
    input  wire        clk,                 
    input  wire        rst_n,       

    // 指令存储器接口 (Instruction Memory Interface)
    output wire [31:0] cpu2instr_addr,       
    output wire        cpu2instr_req,       
    input  wire        instr2cpu_valid,   //1T can ignore it    
    input  wire [31:0] instr2cpu_rdata,     

    // 数据存储器接口 (Data Memory Interface)
    output wire [31:0] cpu2data_addr,       
    output wire [31:0] cpu2data_wdata,      
    output wire        cpu2data_we, 
    output wire        cpu2data_rd,
    output wire [3:0]  cpu2data_be,        
    output wire        cpu2data_req,
    output wire        imem_stall,
    input  wire        data2cpu_gnt,        
    input  wire [31:0] data2cpu_rdata,      
    input  wire        data2cpu_valid,      

    // 中断接口
    input  wire        int2cpu_ext,         
    input  wire        int2cpu_tmr,         
    input  wire        int2cpu_sft          
);

wire    [31:0]          ex_mem_wdata;
wire    [3:0]           ex_be;
assign cpu2data_we  = ex_mem_write_en;
assign cpu2data_rd  = ex_mem_read_en;
assign cpu2data_addr= alu_result;
assign cpu2data_wdata   = ex_mem_wdata;
assign cpu2data_be      = ex_be;
   //linkwire
    wire            load_stall;
    wire            global_stall;
    wire            fence_stall;
    wire            flush;
    wire            flush_ex_jal;
    wire            global_flush;
    wire            branch_taken;
    wire            mem_ready;
    
   //link wire
    wire    if_id_stall = load_stall | fence_stall | global_stall| !mem_ready;
    wire    [31:0]      if_pc;
    wire    [31:0]      if_inst;
    wire                if_valid;
    wire    [31:0]      jump_pc_if; //hazard to if 
    wire                jump_to_if;
 
assign imem_stall = if_id_stall;

    if_stage u_if(
    .clk        (clk),
    .rst_n      (rst_n),

    .stall      (if_id_stall),
    .flush      (flush), 

    .inst_addr  (cpu2instr_addr),
    .inst_req   (cpu2instr_req),
    .inst_data  (instr2cpu_rdata),
    .inst_valid   (instr2cpu_valid),

    .jump_pc    (jump_pc_if),    // jump pc
    .jump_en    (jump_to_if),    // jump or branch enable
    .if_pc          (if_pc),         
    .if_inst        (if_inst),  
    .if_valid       (if_valid)
        );


    //link wire
    wire    [31:0]  if_id_pc;
    wire    [31:0]  if_id_inst;
    wire            if_id_valid;
    wire    [4:0]   if_id_rs1;
    wire    [4:0]   if_id_rs2;
    
    //fi_id
    if_id   u_if_id(

    .clk        (clk),
    .rst_n      (rst_n),
    .stall      (if_id_stall),      
    .flush      (flush),      
    
    // frome  IF 
    .if_pc      (if_pc),
    .if_inst    (if_inst),
    .if_valid   (if_valid),
    // sent to  ID 
    .id_pc      (if_id_pc),
    .id_inst    (if_id_inst),
    .id_valid   (if_id_valid),
    //to hazard
    .if_id_rs1  (if_id_rs1),
    .if_id_rs2  (if_id_rs2)
        );

    // link wire
    //reg_file
    wire    [4:0]   id_rs1_addr, id_rs2_addr;
    wire    [31:0]  id_rs1_data, id_rs2_data;

    //to ex
    wire    [3:0]   id_alu_op;
    wire    [31:0]  id_alu_rs1, id_alu_rs2;
    wire    [31:0]  id_imm_ext;
    wire    [1:0]   id_alu_a_sel;
    wire    [1:0]   id_alu_b_sel;
    wire            id_rs1_use;
    wire            id_rs2_use;
    wire            id_jump_r;
    wire            id_branch_en;
    //data mem
    wire            id_mem_read_en, id_mem_write_en;
    wire    [2:0]   id_mem_width;
    //to hazard
    wire            id_jump_en;
    wire    [31:0]  id_jump_pc;
    wire            id_ebreak_en;// EBREAK
    wire            id_ecall_en; // ECALL
    wire            id_fence_en; // FENCE
    wire            id_illegal_instr;
    //reg_wb
    wire    [4:0]   id_rd_addr;
    wire            id_reg_write_en;
    wire            id_wb_sel; // 0: ALU, 1: Mem

    
    //id
    id_stage u_id (
        //frome if
        .instr_i        (if_id_inst),
        .inst_valid     (if_id_valid),
        .inst_pc        (if_id_pc),
        //to reg file
        .rs1_addr       (id_rs1_addr),
        .rs2_addr       (id_rs2_addr),
        .rs1_data       (id_rs1_data),
        .rs2_data       (id_rs2_data),

             
        //to ex
        .alu_op         (id_alu_op),
        .alu_in_rs1     (id_alu_rs1),
        .alu_in_rs2     (id_alu_rs2),
        .imm_ext        (id_imm_ext),
        .alu_a_sel      (id_alu_a_sel),
        .alu_b_sel      (id_alu_b_sel),
        .rs1_use        (id_rs1_use),//to hazard also
        .rs2_use        (id_rs2_use),
        .jump_r         (id_jump_r),
        .branch_en      (id_branch_en),

        //deliver until mem
        .mem_read_en    (id_mem_read_en),
        .mem_write_en   (id_mem_write_en),
        .mem_width      (id_mem_width),
        //to hazard
        .jump_en        (id_jump_en),
        .pc_jump        (id_jump_pc),
        .ebreak_en      (id_ebreak_en),
        .ecall_en       (id_ecall_en),
        .fence_en       (id_fence_en),
        .illegal_instr  (id_illegal_instr),
        //reg_wb_delivey
        .rd_addr        (id_rd_addr),
        .reg_write_en   (id_reg_write_en),
        .wb_sel         (id_wb_sel),
        
        .load_stall     (load_stall)

    );
    // link wire
    wire        [3:0]   ex_alu_op;
    wire        [31:0]  ex_alu_rs1;
    wire        [31:0]  ex_alu_rs2;
    wire        [31:0]  ex_alu_imm;
    wire        [1:0]   ex_a_sel;
    wire        [1:0]   ex_b_sel;
    wire                ex_rs1_use;
    wire                ex_rs2_use;
    wire        [2:0]   ex_funct3;
    wire                ex_branch_en;
    wire                ex_jump_r;

    wire        [4:0]   ex_rs1_addr;    // Forwarding/hazard Unit
    wire        [4:0]   ex_rs2_addr;
    
    // EX/MEM 
    wire        [4:0]   ex_rd_addr;//to hazard and ex_mem,forward
    wire                ex_mem_read_en;
    wire                ex_mem_write_en;
    wire        [2:0]   ex_mem_width;
    //delivery 
    wire        [31:0]  ex_pc;
    wire        [31:0]  ex_inst;
    wire                ex_valid;
    //wb
    wire                ex_reg_write_en;
    wire                ex_wb_sel;
    wire                ex_fence;

    wire        [31:0]  branch_or_jump_pc;
    wire                id_ex_stall;
    assign  id_ex_stall = global_stall | mem_stall;
id_ex u_id_ex (
    .clk            (clk),
    .rst_n          (rst_n),
    .global_stall   (id_ex_stall),//global stall
    .stall          (load_stall),//load_use stall
    .flush          (flush_ex_jal),
    //from if_id 
    .id_pc          (if_id_pc),
    .id_inst        (if_id_inst),
    .id_valid       (if_id_valid),
    //from id
    .id_alu_op      (id_alu_op),
    .id_alu_rs1     (id_alu_rs1),
    .id_alu_rs2     (id_alu_rs2),
    .id_imm_ext     (id_imm_ext),
    .id_a_sel       (id_alu_a_sel),
    .id_b_sel       (id_alu_b_sel),
    .id_rs1_use     (id_rs1_use),
    .id_rs2_use     (id_rs2_use),
    .id_branch_en   (id_branch_en),
    .id_jump_r      (id_jump_r),
    
    .id_mem_read_en (id_mem_read_en),
    .id_mem_write_en(id_mem_write_en),
    .id_mem_width   (id_mem_width),

    .id_rd_addr     (id_rd_addr),
    .id_reg_write_en(id_reg_write_en),
    .id_wb_sel      (id_wb_sel),
    .id_fence       (id_fence_en),

    .id_rs1_addr    (id_rs1_addr),
    .id_rs2_addr    (id_rs2_addr),//judge hazard
    // to ex
    .ex_alu_op      (ex_alu_op),
    .ex_alu_rs1     (ex_alu_rs1),//
    .ex_alu_rs2     (ex_alu_rs2),// also ro ex_mem
    .ex_alu_imm     (ex_alu_imm),
    .ex_a_sel       (ex_a_sel),
    .ex_b_sel       (ex_b_sel),
    .ex_rs1_use     (ex_rs1_use),//also to forward hazard
    .ex_rs2_use     (ex_rs2_use),
    .ex_funct3      (ex_funct3),//also to ex_mem sign byte hw w word 
    .ex_branch_en   (ex_branch_en),
    .ex_jump_r      (ex_jump_r),
    //to forward and next pipel reg
    .ex_rs1_addr    (ex_rs1_addr),
    .ex_rs2_addr    (ex_rs2_addr),
    //to ex_mem  
    .ex_mem_read_en  (ex_mem_read_en),
    .ex_mem_write_en (ex_mem_write_en),
    .ex_mem_width    (ex_mem_width),
    .ex_fence        (ex_fence),
    //delivery
    .ex_pc          (ex_pc),
    .ex_inst        (ex_inst),
    .ex_valid       (ex_valid),
    //wb
    .ex_rd_addr     (ex_rd_addr),//also to hazard
    .ex_reg_write_en(ex_reg_write_en),
    .ex_wb_sel      (ex_wb_sel)
    );
    wire                wb_fence;    
    wire                mem_fence;
    wire                mem_stall;
hazard u_hazard (
    .clk            (clk),
    .rst_n          (rst_n),
    //load ues hazard
    .id_ex_rd       (ex_rd_addr),
    .id_ex_mem_read (ex_mem_read_en), 
    .if_id_rs1      (if_id_rs1),
    .if_id_rs2      (if_id_rs2),

    .load_stall     (load_stall),
    .fence_stall    (fence_stall),
    .global_stall   (global_stall),
    .mem_stall      (mem_stall),
    .flush          (flush),
    .flush_ex_jal   (flush_ex_jal),
    .global_flush   (global_flush),

    //jump or branch
    .jump_en         (id_jump_en),
    .jump_pc         (id_jump_pc),
    .branch_taken    (branch_taken),
    .branch_pc       (branch_or_jump_pc),//alu to hazard
    .wb_fence        (wb_fence),
    .mem_fence       (mem_fence),
    .jump_to_if      (jump_to_if),
    .jump_pc_if      (jump_pc_if),

    .mem_ready          (mem_ready),
    .id_ebreak_en       (id_ebreak_en),
    .id_ecall_en        (id_ecall_en),
    .id_fence_en        (id_fence_en),
    .id_illegal_instr   (id_illegal_instr)

);
//link wire

    wire        [4:0]   mem_rd_addr;
    wire        [4:0]      wb_addr;
    wire                mem_reg_write_en;
    wire                wb_en;
    wire    [1:0]   mem_forward_en;//[1] rs1 [0] rs2
    wire    [1:0]   wb_forward_en;
forward u_forward(
    .for_id_rs1         (ex_rs1_addr),
    .for_id_rs2         (ex_rs2_addr),
    .for_rs1_use        (ex_rs1_use),
    .for_rs2_use        (ex_rs2_use),
    .for_mem_rd         (mem_rd_addr),
    .for_wb_rd          (wb_addr),
    .for_mem_reg_write  (mem_reg_write_en),
    .for_wb_reg_write   (wb_en),
    .mem_forward_en     (mem_forward_en),
    .wb_forward_en      (wb_forward_en)
 ); 

 //link wire 
 wire   [31:0]  mem_forward_data;
 wire   [31:0]  updated_rs2;
 wire   [31:0]  alu_result;
 wire        [31:0]      wb_data;

    ex_stage u_ex (
        .ex_alu_op          (ex_alu_op),
        .ex_alu_rs1         (ex_alu_rs1),
        .ex_alu_rs2         (ex_alu_rs2),
        .ex_alu_imm         (ex_alu_imm),
        .ex_a_sel           (ex_a_sel),
        .ex_b_sel           (ex_b_sel),
        .ex_rs1_use         (ex_rs1_use),
        .ex_rs2_use         (ex_rs2_use),
        .ex_funct3          (ex_funct3),
        .ex_branch_en       (ex_branch_en),
        .ex_jump_r          (ex_jump_r),
        .ex_pc              (ex_pc),
        .mem_forward_en     (mem_forward_en),//forward
        .wb_forward_en      (wb_forward_en),
        .mem_forward_data   (mem_forward_data),
        .wb_forward_data    (wb_data),
        .alu_result_o       (alu_result),
        .updated_rs2        (updated_rs2),
        .branch_taken       (branch_taken),
        .branch_or_jump_pc  (branch_or_jump_pc),
        .ex_mem_wdata       (ex_mem_wdata),
        .ex_be              (ex_be)
    );
// link wire
        wire                mem_mem_write_en;
        wire                mem_mem_read_en;
        wire        [2:0]   mem_mem_width;
        wire        [31:0]  mem_alu_result; //also to wb
        wire        [31:0]  mem_updated_rs2;//updated_rs2
    //to mem_wb
        //wire        [4:0]   mem_rd_addr;
        //wire                mem_reg_write_en;
        wire                mem_wb_sel;

        wire        [31:0]  mem_pc;
        
ex_mem u_ex_mem (
        .clk                (clk),
        .rst_n              (rst_n),
    
        .flush              (global_flush),
        .stall              (mem_stall),
    //frome id_ex
    //to mem
        .ex_mem_write_en    (ex_mem_write_en),
        .ex_mem_read_en     (ex_mem_read_en),
        .ex_mem_width       (ex_mem_width),//funct3
    
    //wb
        .ex_rd_addr         (ex_rd_addr),
        .ex_reg_write_en    (ex_reg_write_en),
        .ex_wb_sel          (ex_wb_sel),
        .ex_fence           (ex_fence),

        .ex_pc              (ex_pc),
    
    //forme ex
        .ex_alu_result      (alu_result),//store addr or write reg data
        .ex_updated_rs2     (updated_rs2),//store data
    
    // to mem
        .mem_mem_write_en   (mem_mem_write_en),
        .mem_mem_read_en    (mem_mem_read_en),
        .mem_mem_width      (mem_mem_width),
        .mem_alu_result     (mem_alu_result), //also to wb
        .mem_updated_rs2    (mem_updated_rs2),//updated_rs2
    //to mem_wb
        .mem_rd_addr        (mem_rd_addr),//to forward also
        .mem_reg_write_en   (mem_reg_write_en),
        .mem_wb_sel         (mem_wb_sel),
        .mem_fence          (mem_fence),
        //to ex
        .mem_forward_data   (mem_forward_data),
        .mem_pc             (mem_pc)
        );
//link wire
    wire        [31:0]  mem_load_data;
   

mem_stage u_mem_stage (
        .mem_mem_write_en   (mem_mem_write_en),
        .mem_mem_read_en    (mem_mem_read_en),
        .mem_funct3         (mem_mem_width),      
        .mem_alu_result     (mem_alu_result),  
        .mem_updated_rs2    (mem_updated_rs2), 

        .dmem_rdata         (data2cpu_rdata),      
        .dmem_gnt           (data2cpu_gnt), //1T ignore it      
        .dmem_valid         (data2cpu_valid),
        .dmem_req           (cpu2data_req), //ignore it
        .mem_write_en       (),// to data mem
        .mem_read_en        (),
        .dmem_addr          (),//to data mem
        .dmem_be            (),
        .dmem_wdata         (),

        .mem_load_data      (mem_load_data),//to wb    
        .mem_ready          (mem_ready)//stall to hazard     
);
//link wire
    //wire        [31:0]      wb_data;
    //wire        [4:0]      wb_addr;
    //wire                    wb_en;
    wire            [31:0]      wb_pc;
 mem_wb u_mem_wb (
        .clk                (clk),
        .rst_n              (rst_n),
        .mem_pc             (mem_pc),

        .stall              (global_stall),
        .flush              (global_flush),

        .mem_rd_addr        (mem_rd_addr),
        .mem_reg_write_en   (mem_reg_write_en),
        .mem_wb_sel         (mem_wb_sel),
        .mem_fence          (mem_fence),
        .mem_alu_result     (mem_alu_result),
        .mem_load_data      (mem_load_data),

        .wb_data            (wb_data),
        .wb_addr            (wb_addr),
        .wb_en              (wb_en),
        .wb_pc              (wb_pc),
        .wb_fence           (wb_fence)
        );




        //  (Register File) 
    reg_file u_reg_file (
        .clk      (clk),
        .rst_n    (rst_n),
        .rs1_addr (id_rs1_addr),
        .rs2_addr (id_rs2_addr),
        .rd_addr  (wb_addr),
        .wr_en    (wb_en),
        .wr_data  (wb_data),
        .rs1_data (id_rs1_data),
        .rs2_data (id_rs2_data)
    );

endmodule

