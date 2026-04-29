module if_stage (
    input   wire            clk,
    input   wire            rst_n,
    
    input   wire            stall,//global stall or load stall is same      
    input   wire            flush,//jump or branch make flush 1; 

    output  wire    [31:0]      inst_addr,//pc to if
    output  wire                inst_req,
    input   wire    [31:0]      inst_data,
    input   wire                inst_valid,
    // frome  EX or  MEM 
    input   wire    [31:0]      jump_pc, //this is jump or branch   
    input   wire                jump_en,    
    //  (IF/ID )
    output  reg     [31:0]      if_pc,  // PC to compute jump pc or ...
    output  reg     [31:0]      if_inst,       // 
    output  reg                 if_valid   //can not use
);

    reg             [31:0]      curr_pc;
    reg             [31:0]      pc_last;//inst is 1T latency so mark last pc    
    reg             [31:0]      reg_inst;
    reg                         reg_stall;

    // jump > stall > +4
    always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        curr_pc <= 32'h0;
    else if (jump_en)
        curr_pc <= jump_pc + 4;
    else if(!stall) 
        curr_pc <= curr_pc +4;
     else curr_pc <=pc_last ; 
end
    
    assign  inst_addr = (jump_en)   ? jump_pc  :  
                        ((stall)    ? pc_last  : curr_pc);//jump direct fetch
    assign  inst_req  = (rst_n) & (jump_en | (!stall) )  ;

    always @ (posedge clk  or negedge rst_n) begin
        if(!rst_n) begin
        pc_last <= 0;
        reg_stall <= 0;
    end
        else if (stall )begin 
        pc_last <= pc_last;
        reg_stall <= stall;
    end else begin
        pc_last <= inst_addr;
        reg_stall <= stall;
    end
    end
always @ (posedge clk  or negedge rst_n) begin
        if(!rst_n) begin
        reg_inst<= 0;
    end
        else if (reg_stall )begin 
        reg_inst<= reg_inst;
    end else begin
        reg_inst<= inst_data;
    end
    end
    always @(*) begin//require output at same time
    if(flush)begin
        if_pc       = jump_pc;
        if_inst     = 32'h00000013;//nop
        if_valid    = 0;
    
    end else if(stall) begin//stall next T is keep pc & inst
        if_pc   = pc_last;
        if_inst = inst_data;
        if_valid= 1;
    end else  if(inst_valid) begin
            if_pc   = pc_last;//pc inst valid syn
            if_inst = inst_data;
            if_valid = 1;
    end else begin  //!inst_valid
        if_pc   = 0;
        if_inst = 32'h00000013;
        if_valid= 0;
    end
end 

endmodule
