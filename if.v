/*module if_stage#(
    parameter BTB_SETS  = 32,
    parameter BHT_SIZE  = 1024,
    parameter GHR_WIDTH = 10,
    parameter RAS_SIZE  = 8
)(
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
    output  reg                 if_valid,   //can not use


    // 分支预测模块加入的端口
    // output  wire  [31:0] fetch_pc必须是取指令的pc，直接接inst_addr就可以 
    output  wire                fetch_valid,//给bpu的就用fetch开头的了
    input   wire                pred_taken,
    input   wire    [31:0]      pred_target,
    input   wire    [GHR_WIDTH + 10 + $clog2(RAS_SIZE) : 0] pred_info,
    //然后需要把预测结果传递给后面 if_id以及id_ex
    output  reg                 if_pred_taken,
    output  reg     [31:0]      if_pred_target,
    output  reg     [GHR_WIDTH + 10 + $clog2(RAS_SIZE) : 0] if_pred_info
);

    reg             [31:0]      curr_pc;
    reg             [31:0]      pc_last;//inst is 1T latency so mark last pc    
    reg                         if_pred_taken_reg;
    reg             [31:0]      if_pred_target_reg;
    reg             [GHR_WIDTH + 10 + $clog2(RAS_SIZE) : 0] if_pred_info_reg;
    // jump > stall > +4
    always @(posedge clk ) begin
    if (!rst_n)
        curr_pc <= 32'h0;
    else if(pred_taken)
        curr_pc <= pred_target +4;
    else if (jump_en)
        curr_pc <= jump_pc + 4;
    else if(stall) 
        curr_pc <=pc_last;    
    else curr_pc <= curr_pc +4;
end
        //现在jump_pc ex阶段就算然后跑回来，最后还有给bpu模块真担心路径太长
    assign  inst_addr = (pred_taken)    ? pred_target   :
                        (jump_en)       ? jump_pc       :  
                        ((stall)        ? pc_last       : curr_pc);//jump direct fetch
    assign  inst_req  = 1;//(rst_n) & (jump_en | (!stall) )  ;
    // 只有当复位结束、流水线没有被后端暂停、
    assign fetch_valid = rst_n && !stall;
    always @ (posedge clk  ) begin
        if(!rst_n) begin
        pc_last             <= 0;
        if_pred_taken_reg   <= 0;//打一拍预测数据和pc 以及指令对齐然后输出
        if_pred_target_reg  <= 0;
        if_pred_info_reg    <= 0;
    end
    else if (stall )begin 
        pc_last             <= pc_last;
        if_pred_taken_reg   <= if_pred_taken_reg;
        if_pred_target_reg  <= if_pred_target_reg;
        if_pred_info_reg    <= if_pred_info_reg;

    end else begin      //这几个flush都不用清零，flush当周期换新的pc地址，bpu模块也会返回新的预测
        pc_last             <= inst_addr;//但是flush当周期的就要清除了
        if_pred_taken_reg   <= pred_taken;
        if_pred_target_reg  <= pred_target;
        if_pred_info_reg    <= pred_info;

    end
    end




    always @(*) begin//require output at same time
    if(flush)begin
        if_pc       = jump_pc;
        if_inst     = 32'h00000013;//nop
        if_valid    = 0;
        if_pred_taken   = 0;
        if_pred_target  = 0;
        if_pred_info    = 0;
    end else if(stall) begin//stall next T is keep pc & inst
        if_pc   = pc_last;
        if_inst = inst_data;
        if_valid= 1;
        if_pred_taken   = if_pred_taken_reg;
        if_pred_target  = if_pred_target_reg;
        if_pred_info    = if_pred_info_reg;
    end else  if(inst_valid) begin  //stall和valid的行为一样啊，因为stall的时候前面reg已经保持了
        if_pc   = pc_last;//pc inst valid syn
        if_inst = inst_data;
        if_valid = 1;
        if_pred_taken   = if_pred_taken_reg;
        if_pred_target  = if_pred_target_reg;
        if_pred_info    = if_pred_info_reg;
            
    end else begin  //!inst_valid
        if_pc   = 0;
        if_inst = 32'h00000013;
        if_valid= 0;
        if_pred_taken   = 0;
        if_pred_target  = 0;
        if_pred_info    = 0;

    end
end 

endmodule*/


module if_stage #(
    parameter BTB_SETS  = 32,
    parameter BHT_SIZE  = 1024,
    parameter GHR_WIDTH = 10,
    parameter RAS_SIZE  = 8
)(
    input   wire            clk,
    input   wire            rst_n,
    input   wire            stall,
    input   wire            flush,

    output  wire    [31:0]  inst_addr,
    output  wire            inst_req,
    input   wire    [31:0]  inst_data,
    input   wire            inst_valid,
    
    input   wire    [31:0]  jump_pc, 
    input   wire                jump_en,    

    output  reg     [31:0]      if_pc,  
    output  reg     [31:0]      if_inst,       
    output  reg                 if_valid,   

    output  wire                fetch_valid,
    input   wire                pred_taken,
    input   wire    [31:0]      pred_target,
    input   wire    [GHR_WIDTH + 10 + $clog2(RAS_SIZE) : 0] pred_info,

    output  reg                 if_pred_taken,
    output  reg     [31:0]      if_pred_target,
    output  reg     [GHR_WIDTH + 10 + $clog2(RAS_SIZE) : 0] if_pred_info
);

    // -------------------------------------------------------
    // 1. PC 寄存器：它是流水线的起点，必须是 reg
    // -------------------------------------------------------
    reg  [31:0] curr_pc;
    wire [31:0] next_pc;

    // -------------------------------------------------------
    // 2. 下一个 PC 的计算逻辑 (组合逻辑 Mux)
    //    优先级：EX级纠偏 (jump) > IF级预测 (pred) > 顺序执行 (+4)
    // -------------------------------------------------------
    assign next_pc = (jump_en)    ? jump_pc     :  // EX级发现预测错误或强制跳转
                     (pred_taken) ? pred_target  :  // BPU 预测当前 PC 要跳转
                                    (curr_pc + 32'd4); // 默认顺序执行

    // -------------------------------------------------------
    // 3. PC 更新 (时序逻辑)
    // -------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            curr_pc <= 32'h0; // 或你的起始地址
        end else if (!stall) begin
            curr_pc <= next_pc;
        end
        // stall 时 curr_pc 保持不变
    end

    // -------------------------------------------------------
    // 4. 对外接口赋值
    // -------------------------------------------------------
    assign inst_addr   = curr_pc;   // 这一步没问题，当前pc取地址，也给bpu做预测，预测的下一周期更新
    assign fetch_valid = rst_n && !stall;
    assign inst_req    = 1'b1;

    // -------------------------------------------------------
    // 5. 流水线数据对齐 (从 IF 到 ID)
    //    因为指令存储器有 1T 延迟，所以 PC 也需要存一个副本 (pc_at_id)
    // -------------------------------------------------------
    reg [31:0] pc_at_id;
    reg        if_pred_taken_reg;
    reg [31:0] if_pred_target_reg;
    reg [GHR_WIDTH + 10 + $clog2(RAS_SIZE) : 0] if_pred_info_reg;

    always @(posedge clk) begin
        if (!rst_n) begin
            pc_at_id           <= 0;
            if_pred_taken_reg  <= 0;
            if_pred_target_reg <= 0;
            if_pred_info_reg   <= 0;
        end else if (!stall) begin
            if (flush) begin // 如果发生冲刷，清空预测信息
                pc_at_id           <= 0;
                if_pred_taken_reg  <= 0;
                if_pred_target_reg <= 0;
                if_pred_info_reg   <= 0;
            end else begin
                pc_at_id           <= curr_pc; // 这里寄存1拍和对应指令晚1周期回来
                if_pred_taken_reg  <= pred_taken;
                if_pred_target_reg <= pred_target;
                if_pred_info_reg   <= pred_info;
            end
        end
    end
    reg flush_reg;
    always @(posedge clk) begin
        if (!rst_n) flush_reg <= 1'b0;
        else if (stall) flush_reg <= flush_reg; // 如果 stall，保持屏蔽状态
        else flush_reg <= flush;               // 记录上一周期的 flush 动作
    end
    // -------------------------------------------------------
    // 6. 输出到 ID 阶段 (保持你原来的组合逻辑输出习惯)
    // -------------------------------------------------------
    always @(*) begin
        if (flush || flush_reg) begin
            if_pc          = curr_pc; // 暂时先指向当前pc，反正都是nop指令
            if_inst        = 32'h00000013; // NOP
            if_valid       = 1'b0;
            if_pred_taken  = 1'b0;
            if_pred_target = 32'b0;
            if_pred_info   = 0;
        end else begin
            if_pc          = pc_at_id;//这里统一对齐数据输出,也可以再加上inst_valid，多一层保护
            if_inst        = inst_data;
            if_valid       = inst_valid;
            if_pred_taken  = if_pred_taken_reg;
            if_pred_target = if_pred_target_reg;
            if_pred_info   = if_pred_info_reg;
        end
    end

endmodule
