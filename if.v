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
    wire            [31:0]      next_pc;

    // jump > stall > +4
    always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        curr_pc <= 32'h0;
    else if (jump_en)
        curr_pc <= jump_pc + 4;
    else if(!stall && inst_valid) 
        curr_pc <= curr_pc +4;
     else curr_pc <= curr_pc; 
end
    
    assign  inst_addr = (jump_en)   ? jump_pc   : curr_pc;//jump direct fetch
    assign  inst_req  = (rst_n) ? 1 : 0 ;

    always @ (posedge clk  or negedge rst_n) begin
    if(!rst_n) 
        pc_last <= 0;
    else if (!stall ) 
        pc_last <= inst_addr;
    end

    always @(*) begin//require output at same time
    if(flush)begin
        if_pc       = pc_last;
        if_inst     = 32'h00000013;//nop
        if_valid    = 0;
    end else if(stall) begin
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
