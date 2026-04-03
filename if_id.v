module if_id (
    input   wire        clk,
    input   wire        rst_n,
    
    
    input   wire        stall,//global stall or load stall is same      
    input   wire        flush,      
    
    // frome  IF 
    input   wire    [31:0]  if_pc,
    input   wire    [31:0]  if_inst,
    input   wire            if_valid,
    // sent to  ID 
    output  reg     [31:0]  id_pc,//
    output  reg     [31:0]  id_inst,
    output  reg             id_valid,
    // to hazard
    output  wire    [4:0]   if_id_rs1,
    output  wire    [4:0]   if_id_rs1,

);

    // RISC-V NOP instr: addi x0, x0, 0
    localparam [31:0] NOP = 32'h0000_0013;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_pc       <= 32'h0;
            id_inst     <= NOP;
            id_valid    <= 0;
        end else if (flush) begin
            id_pc       <= 32'h0;
            id_inst     <= NOP;
            id_valid    <= 0;
        end else if (!stall) begin
            id_pc       <= if_pc;
            id_inst     <= if_inst;
            id_valid    <= 1;
        end        
    end
assign if_id_rs1    = id_inst[19:15];//may isnot rs1/rs2 addr
assign if_id_rs1    = id_inst[24:20];


endmodule















