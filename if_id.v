module if_id #(
    parameter BTB_SETS  = 32,
    parameter BHT_SIZE  = 1024,
    parameter GHR_WIDTH = 10,
    parameter RAS_SIZE  = 8
)(
    input   wire        clk,
    input   wire        rst_n,
    
    
    input   wire        stall,//global stall or load stall is same      
    input   wire        flush,      
    
    // frome  IF 
    input   wire    [31:0]  if_pc,
    input   wire    [31:0]  if_inst,
    input   wire            if_valid,
    input   wire            if_pred_taken,
    input   wire    [31:0]  if_pred_target,
    input   wire    [GHR_WIDTH + 10 + $clog2(RAS_SIZE) : 0] if_pred_info,
    // sent to  ID 
    output  reg     [31:0]  id_pc,
    output  reg     [31:0]  id_inst,
    output  reg             id_valid,
    output  reg             id_pred_taken,
    output  reg     [31:0]  id_pred_target,
    output  reg     [GHR_WIDTH + 10 + $clog2(RAS_SIZE) : 0] id_pred_info,

    // to hazard
    output  wire    [4:0]   if_id_rs1,
    output  wire    [4:0]   if_id_rs2

);

    // RISC-V NOP instr: addi x0, x0, 0
    localparam [31:0] NOP = 32'h0000_0013;

    always @(posedge clk ) begin
        if (!rst_n) begin
            id_pc       <= 32'h0;
            id_inst     <= NOP;
            id_valid    <= 0;
            id_pred_taken   <= 0;
            id_pred_target  <= 0;
            id_pred_info    <= 0;
        end else if (flush) begin
            id_pc       <= if_pc;
            id_inst     <= NOP;
            id_valid    <= 0;
            id_pred_taken   <= 0;
            id_pred_target  <= 0;
            id_pred_info    <= 0;
        end else if (stall) begin
            id_pc       <= id_pc;
            id_inst     <= id_inst;
            id_valid    <= 1;
            id_pred_taken   <= id_pred_taken;
            id_pred_target  <= id_pred_target;
            id_pred_info    <= id_pred_info;
        end else begin
            id_pc       <= if_pc;
            id_inst     <= if_inst;
            id_valid    <= 1;
            id_pred_taken   <= if_pred_taken;
            id_pred_target  <= if_pred_target;
            id_pred_info    <= if_pred_info;
        end        
    end
assign if_id_rs1    = id_inst[19:15];//may isnot rs1/rs2 addr
assign if_id_rs2    = id_inst[24:20];


endmodule















