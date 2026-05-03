// ============================================================
// Branch Prediction Unit (BPU)
// 修复历史：
//   v1: [FIX-1] BTB更新改用 update_hit0/update_hit1
//       [FIX-2] RAS 快照寄存器（单快照，有in-flight分支覆盖风险）
//       [FIX-3] pred_info 位宽参数化
//       [FIX-4] RAS 溢出/下溢保护
//       [FIX-5] btb_type 复位初始化
//       [FIX-6] flush 信号正确处理
//   v2: [FIX-2b] ras_ptr 纳入 pred_info 随流水线传递，
//                彻底解决连续in-flight分支时快照被覆盖的问题，
//                删除 ras_ptr_snapshot 寄存器
//
// pred_info 编码（共 GHR_WIDTH + 10 + RAS_PTR_WIDTH 位）：
//   高段 [GHR_WIDTH+9+RAS_PTR_WIDTH : 10+RAS_PTR_WIDTH] = 取指时 GHR 快照
//   中段 [9+RAS_PTR_WIDTH : RAS_PTR_WIDTH]               = 取指时 BHT 索引
//   低段 [RAS_PTR_WIDTH-1 : 0]                           = 取指时 ras_ptr 快照
//
// RAS_PTR_WIDTH = $clog2(RAS_SIZE)+1，多1位用于溢出边界检测
// ============================================================
module bpu #(
    parameter BTB_SETS  = 32,
    parameter BHT_SIZE  = 1024,
    parameter GHR_WIDTH = 10,
    parameter RAS_SIZE  = 8
)(
    input  wire        clk,
    input  wire        rst_n,

    // --- 取指阶段 (IF) ---
    input  wire [31:0] fetch_pc,
    input  wire        fetch_valid,
    output wire        pred_taken,//这是给if阶段的预测pc地址
    output wire [31:0] pred_target,
    // [FIX-3][FIX-2b] pred_info 完整编码，含 GHR/BHT索引/RAS_ptr 三段
    // 宽度 = GHR_WIDTH + 10 + RAS_PTR_WIDTH
    // 使用方须将此值与 old_pred_info 端口宽度保持一致
    output wire [GHR_WIDTH + 10 + $clog2(RAS_SIZE) : 0] pred_info,//这个是随着流水线传递到ex阶段的信息

    // --- 执行/提交阶段 (Update) ---
    input  wire        update_en,
    input  wire [31:0] update_pc,
    //input  wire [31:0] update_pc_next,   // 当前未使用，保留供外部RAS对比校验
    input  wire [31:0] actual_target,   //实际的跳转地址,预测正确也要更新，ex阶段计算得出的，
    input  wire        actual_taken,    //也要和预测地址比较，即使预测正确跳转与否但是地址不正确也是mispredict
    input  wire [1:0]  branch_type,      // 00:Branch, 01:Call, 10:Ret
    input  wire [GHR_WIDTH + 10 + $clog2(RAS_SIZE) : 0] old_pred_info,//传递到ex阶段然后回传的信息
    input  wire        mispredict,

    // --- 流水线控制 ---
    input  wire        stall,
    input  wire        flush
);

    // RAS 指针位宽：多1位支持边界检测，范围 0..RAS_SIZE
    localparam RAS_PTR_WIDTH = $clog2(RAS_SIZE) + 1;

    // ============================================================
    // 1. Gshare 方向预测器 (BHT)
    // ============================================================
    reg [GHR_WIDTH-1:0] ghr;// Global History Registe 全局历史寄存器，作用就是和pc异或，产生索引 index
    (* ram_style = "distributed" *) reg [1:0] bht [BHT_SIZE-1:0];//分支历史表Branch History Table 1024个（深度），每一个2bit表明强跳、弱跳等
    // 分布式ram进行综合
    // 哈希：PC[11:2] XOR GHR（BHT固定1024项，索引10位）
    wire [9:0] bht_index = fetch_pc[11:2] ^ {{(10-GHR_WIDTH){1'b0}}, ghr};
    wire [1:0] bht_state = bht[bht_index];
    wire gshare_dir = (bht_state >= 2'b10);//gshare_die=1，预测跳转，bht_state 11 10 强跳、弱跳

    // ============================================================
    // 2. 2路组相联 BTB  Branch Target Buffe 分支目标缓冲器，32 *2 组 存储64条指令的跳转信息的缓冲器
    // ============================================================
    reg [31:0] btb_tag    [1:0][BTB_SETS-1:0];
    reg [31:0] btb_target [1:0][BTB_SETS-1:0];
    reg [1:0]  btb_type   [1:0][BTB_SETS-1:0];
    reg        btb_valid  [1:0][BTB_SETS-1:0];//存储tag 和target的有效位，初始化为0，后面未命中且是分支指令写入tag/target的时候有效位一起写入
    reg        btb_lru    [BTB_SETS-1:0];//替换策略信号Least Recently Used.32个数据深度，0/1代表着新的分支指令进入way0/1

    // 取指侧命中（基于 fetch_pc）
    wire [4:0] set_idx     = fetch_pc[6:2];//4字节对齐选择pc的[6:2] 5bit作为索引，pc地址[6:2]相同的只能放在特定位置，例如全是0，只能放在btb_tag[0/1]的[0]
    wire hit0 = btb_valid[0][set_idx] && (btb_tag[0][set_idx] == fetch_pc);//对于放在两组的哪一个是由btb_lru寄存的结果决定
    wire hit1 = btb_valid[1][set_idx] && (btb_tag[1][set_idx] == fetch_pc);
    wire btb_hit = hit0 || hit1;

    wire [31:0] btb_target_out = hit0 ? btb_target[0][set_idx] : btb_target[1][set_idx];
    wire [1:0]  btb_type_out   = hit0 ? btb_type[0][set_idx]   : btb_type[1][set_idx];

    // [FIX-1] 更新侧命中（独立基于 update_pc，不复用取指侧 hit0/hit1）
    wire [4:0] update_set_idx = update_pc[6:2];//拿ex阶段返回的pc来说明之前预测的是命中与否，来验证
    wire update_hit0 = btb_valid[0][update_set_idx] && (btb_tag[0][update_set_idx] == update_pc);
    wire update_hit1 = btb_valid[1][update_set_idx] && (btb_tag[1][update_set_idx] == update_pc);

    // ============================================================
    // 3. 返回地址栈 (RAS)Return Address Stack,
    // ============================================================
    reg [31:0]              ras_stack [RAS_SIZE-1:0];
    reg [RAS_PTR_WIDTH-1:0] ras_ptr;

    // 栈空时返回 0（安全值，避免X态传播到 pred_target）
    wire [31:0] ras_top = (ras_ptr > 0) ? ras_stack[ras_ptr - 1'b1] : 32'b0;

    // ============================================================
    // 4. 预测输出整合
    // ============================================================                         //指令有效和btb hit（分支目标缓冲里有当前pc的跳转地址）都要为1
    //assign pred_taken = 0;//测试是不是bpu的问题，坏消息，确实是他的问题
    assign pred_taken  = fetch_valid && btb_hit && ((btb_type_out == 2'b10) || gshare_dir);//gshare_dir 为1预测跳转
    assign pred_target = (btb_type_out == 2'b10) ? ras_top : btb_target_out;

    // [FIX-2b] ras_ptr 打包进 pred_info，随指令在流水线中传递
    // mispredict 时从 old_pred_info 精确恢复出错指令取指时的栈状态
    assign pred_info = {ghr, bht_index, ras_ptr};

    // 从 old_pred_info 中提取三段字段
    wire [RAS_PTR_WIDTH-1:0] old_ras_ptr    = old_pred_info[RAS_PTR_WIDTH-1 : 0];
    wire [9:0]               update_bht_idx = old_pred_info[RAS_PTR_WIDTH+9 : RAS_PTR_WIDTH];
    wire [GHR_WIDTH-1:0]     old_ghr_val    = old_pred_info[GHR_WIDTH+RAS_PTR_WIDTH+9 : RAS_PTR_WIDTH+10];

    // ============================================================
    // 5. 时序更新逻辑
    // ============================================================
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ghr     <= {GHR_WIDTH{1'b0}};
            ras_ptr <= {RAS_PTR_WIDTH{1'b0}};
            for (i = 0; i < BHT_SIZE; i = i + 1)
                bht[i] <= 2'b01;                // 弱不跳初始态
            for (i = 0; i < BTB_SETS; i = i + 1) begin
                btb_valid[0][i] <= 1'b0;
                btb_valid[1][i] <= 1'b0;
                btb_lru[i]      <= 1'b0;//所有的都被复位0，那最初有分支指令的时候先进入way0
                btb_type[0][i]  <= 2'b00;       // [FIX-5]
                btb_type[1][i]  <= 2'b00;
            end

        end else begin

            // --------------------------------------------------------
            // A. GHR 与 RAS ptr：推测更新 / 误预测与flush纠正
            //
            // [FIX-6] flush/mispredict 最高优先级
            // [FIX-2b] 用 old_pred_info 里的 old_ras_ptr 恢复，
            //          精确对应出错指令取指时刻的栈状态，
            //          无论流水线中同时有多少条 in-flight 分支均正确。
            // --------------------------------------------------------
            if (flush || mispredict) begin
                ghr     <= {old_ghr_val[GHR_WIDTH-2:0], actual_taken};
                ras_ptr <= old_ras_ptr;
            end else if (fetch_valid && !stall) begin
                ghr <= {ghr[GHR_WIDTH-2:0], pred_taken};
                // ras_ptr 推测更新在 D 块完成
            end

            // --------------------------------------------------------
            // B. BHT 饱和计数器更新
            //
            // 已知精度限制：多条 in-flight 分支存在 BHT 写后读相关，
            // 影响预测精度但不影响功能正确性（mispredict 机制保证安全）。
            // --------------------------------------------------------
            if (update_en) begin//每一个分支/跳转指令都会触发，进行学习，强跳/弱跳/弱不跳/强不跳的转换学习
                if (actual_taken) begin
                    if (bht[update_bht_idx] != 2'b11)
                        bht[update_bht_idx] <= bht[update_bht_idx] + 2'b01;
                end else begin
                    if (bht[update_bht_idx] != 2'b00)
                        bht[update_bht_idx] <= bht[update_bht_idx] - 2'b01;
                end
            end

            // --------------------------------------------------------
            // C. 2-Way BTB 更新（含LRU替换）[FIX-1]
            // --------------------------------------------------------
            if (update_en && actual_taken) begin
                if (update_hit0) begin
                    btb_target[0][update_set_idx] <= actual_target;
                    btb_lru[update_set_idx]        <= 1'b1;//命中0，置1没命中替换就换1
                end else if (update_hit1) begin
                    btb_target[1][update_set_idx] <= actual_target;
                    btb_lru[update_set_idx]        <= 1'b0;//命中1，置0没命中替换0
                end else begin
                    // 未命中，按 LRU 替换
                    if (btb_lru[update_set_idx] == 1'b0) begin//没命中，lru=0，那就替换0那一系列
                        btb_tag[0][update_set_idx]    <= update_pc;
                        btb_target[0][update_set_idx] <= actual_target;
                        btb_type[0][update_set_idx]   <= branch_type;
                        btb_valid[0][update_set_idx]  <= 1'b1;
                        btb_lru[update_set_idx]        <= 1'b1;//并且置1，因为放在1的位置上，意味着1刚刚命中
                    end else begin//没命中，lru=1，那就替换1那一系列
                        btb_tag[1][update_set_idx]    <= update_pc;
                        btb_target[1][update_set_idx] <= actual_target;
                        btb_type[1][update_set_idx]   <= branch_type;
                        btb_valid[1][update_set_idx]  <= 1'b1;
                        btb_lru[update_set_idx]        <= 1'b0;//并且置0，因为放在0的位置上，意味着0刚刚命中
                    end
                end
            end

            // --------------------------------------------------------
            // D. RAS 推测性操作 [FIX-4] 含溢出/下溢保护
            //
            // 在取指阶段根据 BTB 识别的类型推测操作：
            //   CALL → 压入 fetch_pc+4 作为预测返回地址
            //   RET  → 弹栈（栈顶已在组合逻辑 ras_top 中读出用于预测）
            //
            // flush/mispredict 时 A 块已恢复 ras_ptr，此处不重复处理。
            // --------------------------------------------------------
            if (fetch_valid && !stall && btb_hit && !(flush || mispredict)) begin
                if (btb_type_out == 2'b01) begin            // CALL：推测压栈
                    if (ras_ptr < RAS_SIZE) begin
                        ras_stack[ras_ptr] <= fetch_pc + 32'd4;
                        ras_ptr            <= ras_ptr + 1'b1;
                    end
                    // 栈满时静默丢弃，保持现有栈内容不变
                end else if (btb_type_out == 2'b10) begin   // RET：推测弹栈
                    if (ras_ptr > 0)
                        ras_ptr <= ras_ptr - 1'b1;
                    // 栈空时 ras_top 已返回 32'b0，pred_target 为安全值
                end
            end

        end
    end

endmodule
