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
    input  wire        data2cpu_gnt,        
    input  wire [31:0] data2cpu_rdata,      
    input  wire        data2cpu_valid,      

    // 中断接口
    input  wire        int2cpu_ext,         
    input  wire        int2cpu_tmr,         
    input  wire        int2cpu_sft          
);



    // ALU 
    wire [31:0] alu_result;
    wire        alu_zero;


    
   //link wire
    wire    [31:0]      if_pc;
    wire    [31:0]      if_inst;
    wire                if_valid;
    wire    [31:0]      jump_pc_if //hazard to if 
    wire                jump_to_if
 
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
    wire    if_id_stall = load_stall | global_stall;
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
    wire    [4:0]   rs1_addr, rs2_addr;
    wire    [31:0]  rs1_data, rs2_data;

    wire    [4:0]   rd_addr;
    wire            reg_write_en;
    wire            wb_sel; // 0: ALU, 1: Mem

    wire    [3:0]   alu_op;
    wire    [31:0]  alu_in_a, alu_in_b;
    wire    [2:0]   alu_sign_ab;

    wire    [31:0]  id_rs2_data;
    wire            mem_read_en, mem_write_en;
    wire    [2:0]   mem_width;
    wire            id_branch_en;
    wire            id_jump_en;
    wire            id_jump_pc;
    wire            ebreak_en;// EBREAK
    wire            ecall_en; // ECALL
    wire            fence_en; // FENCE
    wire            illegal_instr;
    wire            id_rs1_use;
    wire            id_rs2_use;
    
    //id
    id_stage u_id (
        //frome if
        .instr_i        (if_id_inst),
        .inst_valid     (if_id_valid),
        .inst_pc        (if_id_pc),
        //to reg file
        .rs1_addr       (rs1_addr),
        .rs2_addr       (rs2_addr),
        .rs1_data       (rs1_data),
        .rs2_data       (rs2_data),

        //deliver until to wb rs1/2/rd addr should deliver 
        .rd_addr        (rd_addr),
        .reg_write_en   (reg_write_en),
        .wb_sel         (wb_sel),

        //to alu
        .alu_op         (alu_op),
        .alu_in_a       (alu_in_a),
        .alu_in_b       (alu_in_b),
        .sign_ab        (alu_sign_ab),
        //deliver until mem
        .id_rs2_data    (id_rs2_data),
        .mem_read_en    (mem_read_en),
        .mem_write_en   (mem_write_en),
        .mem_width      (mem_width),
        //jump
        .branch_en      (id_branch_en),
        //neednt deliver
        .jump_en        (id_jump_en),
        .pc_jump        (id_jump_pc),
        //other
        .ebreak_en      (ebreak_en),
        .ecall_en       (ecall_en),
        .fence_en       (fence_en),
        .illegal_instr  (illegal_instr),
        //to id_ex sign rs1/rs2 use
        .rs1_use        (id_rs1_use),
        .rs2_use        (id_rs2_use)

    );
    // link wire
    wire        [3:0]   ex_alu_op;
    wire        [31:0]  ex_alu_in_a;
    wire        [31:0]  ex_alu_in_b;
    wire        [1:0]   ex_sign_ab;
    wire        [3:0]   ex_funct3;
    wire                ex_branch_en;

    wire        [4:0]   ex_rs1_addr;    // Forwarding/hazard Unit
    wire        [4:0]   ex_rs2_addr;
    wire                ex_rs1_use;
    wire                ex_rs2_use;
    
    // EX/MEM & MEM/WB 
    wire        [4:0]   ex_rd_addr;//to hazard and ex_mem
    wire        [31:0]  ex_rs2_data; // MEM Store data
    wire                ex_mem_read_en;
    wire                ex_mem_write_en;
    wire        [2:0]   ex_mem_width;
    //delivery 
    wire        [31:0]  ex_id_pc;
    wire        [31:0]  ex_id_inst;
    wire                ex_id_valid;
    //wb
    wire                ex_reg_write_en;
    wire                ex_wb_sel;

    wire        [31:0]  branch_pc;

id_ex u_id_ex (
    .clk            (clk),
    .rst_n          (rst_n),
    .global_stall   (global_stall),//global stall
    .stall          (load_stall),//load_use stall
    .flush          (flush),
    //from if_id 
    .id_pc          (if_id_pc),
    .id_inst        (if_id_inst),
    .id_valid       (if_id_valid),
    //from id
    .id_rd_addr     (rd_addr),
    .id_reg_write_en(reg_write_en),
    .id_wb_sel      (wb_sel),
    
    .id_rs1_addr    (rs1_addr),
    .id_rs2_addr    (rs2_addr),//judge hazard

    .alu_op         (alu_op),
    .alu_in_a       (alu_in_a),
    .alu_in_b       (alu_in_b),
    .sign_ab        (alu_sign_ab),
    .id_rs1_use     (id_rs1_use),
    .id_rs2_use     (id_rs2_use),

    .id_mem_read_en (mem_read_en),
    .id_mem_write_en(mem_write_en),
    .id_mem_width   (mem_width),

    .id_branch_en   (id_branch_en),
    // to ex
    .ex_alu_op      (ex_alu_op),
    .ex_alu_in_a    (ex_alu_in_a),
    .ex_alu_in_b    (ex_alu_in_b),
    .ex_sign_ab     (ex_sign_ab),
    .ex_branch_en   (ex_branch_en),
    .ex_funct3      (ex_funct3)
    //to forward and next pipel reg
    .ex_rs1_addr    (ex_rs1_addr),
    .ex_rs2_addr    (ex_rs2_addr),
    .ex_rs1_use     (ex_rs1_use),
    .ex_rs2_use     (ex_rs2_use),
    //to ex_mem
    .o_rd_addr      (ex_rd_addr), //to hazard and ex_mem
    .o_rs2_data     (ex_rs2_data),
    .o_mem_read_en  (ex_mem_read_en),//to hazard and ex_mem
    .o_mem_write_en (ex_mem_write_en),
    .o_mem_width    (ex_mem_width),
    //delivery
    .o_id_pc        (ex_pc),
    .o_id_inst      (ex_inst),
    .o_id_valid     (ex_valid),
    //wb
    .o_reg_write_en (ex_reg_wirte_en),
    .wb_sel         (ex_wb_sel),
    //hazard 
    .branch_pc      (branch_pc) //special ex stage get branch or not id_ex is pc
    );
   //linkwire
    wire            load_stall;
    wire            global_stall;
    wire            flush;
hazard u_hazard (
    //load ues hazard
    .id_ex_rd       (ex_rd_addr),
    .id_ex_mem_read (ex_mem_read_en), 
    .if_id_rs1      (if_id_rs1),
    .if_id_rs2      (if_id_rs2),

    .load_stall     (load_stall),
    .global_stall   (global_stall),
    .flush          (flush)

    //jump or branch
    jump_en         (id_jump_en),
    jump_pc         (id_jump_pc),
    branch_taken    (branch_taken),
    branch_pc       (branch_pc),

    jump_to_if      (jump_to_if),
    jump_pc_if      (jump_pc_if)


);
//link wire

    wire    [4:0]   for_mem_rd,
    wire    [4:0]   for_wb_rd, 
    wire            for_mem_reg_write,
    wire            for_wb_reg_write, 

    wire    [1:0]   mem_forward_en,//[1] rs1 [0] rs2
    wire    [1:0]   wb_forward_en,
forward u_forward(
    .for_id_rs1         (ex_rs1_addr),
    .for_id_rs2         (ex_rs2_addr),
    .for_rs1_use        (ex_rs1_use),
    .for_rs2_use        (ex_rs2_use),
    .for_mem_rd         (for_mem_rd),
    .for_wb_rd          (for_wb_rd),
    .for_mem_reg_write  (for_mem_reg_wire),
    .for_wb_reg_write   (for_wb_reg_write),
    .mem_forward_en     (mem_forward_en),
    .wb_forward_en      (wb_forward_en)
 ); 

 //link wire 
 wire   [31:0]  mem_forward_data;
 wire   [31:0]  mem_forward_data;
 wire           branch_taken;

    ex_stage u_ex (
        .alu_src_a              (alu_in_a),
        .alu_src_b              (alu_in_b),
        .sign_ab                (alu_sign_ab),
        .decoder2alu_sel        (alu_op),
        .ex_funct3              (ex_funct3),
        .branch_en              (ex_branch_en),
        .mem_forward_en         (mem_forward_en),//forward
        .wb_forward_en          (wb_forward_en),
        .mem_forward_data       (mem_forward_data),
        .wb_forward_data        (wb_forward_data),
        .alu_result_o           (alu_result),
        .alu_zero_o             (alu_zero),
        .branch_taken           (branch_taken)
    );

    assign cpu2instr_req  = 1'b1; // requie instruction 



     
    // --- 5. 存储器接口处理 (Load/Store) ---
    assign cpu2data_addr  = alu_result;
    assign cpu2data_wdata = rs2_data;//if write in mem addr and data is must this
    assign cpu2data_we    = mem_write_en;
    assign cpu2data_rd    = mem_read_en;
    assign cpu2data_req   = mem_read_en || mem_write_en;
    
    // 生成字节使能 (BE)，用于 SB, SH, SW 指令
    assign cpu2data_be = (mem_width == 3'b000) ? (4'b0001 << alu_result[1:0]) : // Byte
                         (mem_width == 3'b001) ? (4'b0011 << alu_result[1:0]) : // Half
                         (mem_width == 3'b010) ? 4'b1111 : // Word
                                                 4'b0000;
    // --- Load Data Extender ---
reg [31:0] load_data_final;
wire [1:0] addr_offset = alu_result[1:0]; // low 2 bit  make sure byte offset 

always @(*) begin
    case (mem_width) //  funct3
        3'b000: begin // LB (Load Byte, Sign Extended)
            case (addr_offset)
                2'b00: load_data_final = {{24{data2cpu_rdata[7]}},  data2cpu_rdata[7:0]};
                2'b01: load_data_final = {{24{data2cpu_rdata[15]}}, data2cpu_rdata[15:8]};
                2'b10: load_data_final = {{24{data2cpu_rdata[23]}}, data2cpu_rdata[23:16]};
                2'b11: load_data_final = {{24{data2cpu_rdata[31]}}, data2cpu_rdata[31:24]};
            endcase
        end
        
        3'b001: begin // LH (Load Halfword, Sign Extended)
            // addr_offset  00 / 10
            if (addr_offset[1] == 1'b0)
                load_data_final = {{16{data2cpu_rdata[15]}}, data2cpu_rdata[15:0]};
            else
                load_data_final = {{16{data2cpu_rdata[31]}}, data2cpu_rdata[31:16]};
        end
        
        3'b010: begin // LW (Load Word)
            load_data_final = data2cpu_rdata;
        end
        
        3'b100: begin // LBU (Load Byte, Zero Extended)
            case (addr_offset)
                2'b00: load_data_final = {24'b0, data2cpu_rdata[7:0]};
                2'b01: load_data_final = {24'b0, data2cpu_rdata[15:8]};
                2'b10: load_data_final = {24'b0, data2cpu_rdata[23:16]};
                2'b11: load_data_final = {24'b0, data2cpu_rdata[31:24]};
            endcase
        end
        
        3'b101: begin // LHU (Load Halfword, Zero Extended)
            if (addr_offset[1] == 1'b0)
                load_data_final = {16'b0, data2cpu_rdata[15:0]};
            else
                load_data_final = {16'b0, data2cpu_rdata[31:16]};
        end
        
        default: load_data_final = data2cpu_rdata;
    endcase
end
    //   (Write-back to reg) ---

    wire    [31:0]  rf_write_data;

    always @(*) begin
        if (wb_sel) 
            rf_write_data = load_data_final; // 从内存读出的数据
        else        
            rf_write_data = alu_result;     // ALU 结果 (包含算术结果和 PC+4)
    end

wire reg_write_finen = reg_write_en && (mem_read_en ? data2cpu_valid : 1'b1);
    //  (Register File) 
    reg_file u_reg_file (
        .clk      (clk),
        .rst_n    (rst_n),
        .rs1_addr (rs1_addr),
        .rs2_addr (rs2_addr),
        .rd_addr  (rd_addr),
        .wr_en    (reg_write_finen),
        .wr_data  (rf_write_data),
        .rs1_data (rs1_data),
        .rs2_data (rs2_data)
    );

endmodule

