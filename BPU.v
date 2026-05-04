// ============================================================
// Branch Prediction Unit (BPU) - Optimized for FPGA Resource
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
    output wire        pred_taken,
    output wire [31:0] pred_target,
    output wire [GHR_WIDTH + 10 + $clog2(RAS_SIZE) : 0] pred_info,

    // --- 执行/提交阶段 (Update) ---
    input  wire        update_en,
    input  wire [31:0] update_pc,
    input  wire [31:0] actual_target, 
    input  wire        actual_taken,  
    input  wire [1:0]  branch_type,   
    input  wire [GHR_WIDTH + 10 + $clog2(RAS_SIZE) : 0] old_pred_info,
    input  wire        mispredict,

    // --- 流水线控制 ---
    input  wire        stall,
    input  wire        flush
);

    localparam RAS_PTR_WIDTH = $clog2(RAS_SIZE) + 1;

    // ============================================================
    // 1. 存储阵列声明
    // ============================================================
    // Gshare BHT
    (* ram_style = "distributed" *) reg [1:0] bht [BHT_SIZE-1:0];
    reg [GHR_WIDTH-1:0] ghr;

    // 2-Way BTB
    reg [31:0] btb_tag    [1:0][BTB_SETS-1:0];
    reg [31:0] btb_target [1:0][BTB_SETS-1:0];
    reg [1:0]  btb_type   [1:0][BTB_SETS-1:0];
    reg        btb_valid  [1:0][BTB_SETS-1:0];
    reg        btb_lru    [BTB_SETS-1:0];

    // RAS
    reg [31:0]              ras_stack [RAS_SIZE-1:0];
    reg [RAS_PTR_WIDTH-1:0] ras_ptr;

    // ============================================================
    // 2. 上电初始化 (取代异步复位以节省资源)
    // ============================================================
    integer i;
    initial begin
        // 初始化 BHT: 弱不跳 2'b01
        for (i = 0; i < BHT_SIZE; i = i + 1) begin
            bht[i] = 2'b01;
        end
        // 初始化 BTB: 有效位清零
        for (i = 0; i < BTB_SETS; i = i + 1) begin
            btb_valid[0][i] = 1'b0;
            btb_valid[1][i] = 1'b0;
            btb_lru[i]      = 1'b0;
            btb_type[0][i]  = 2'b00;
            btb_type[1][i]  = 2'b00;
        end
        // 初始化 RAS 栈
        for (i = 0; i < RAS_SIZE; i = i + 1) begin
            ras_stack[i] = 32'b0;
        end
    end

    // ============================================================
    // 3. 组合逻辑 (保持不变)
    // ============================================================
    wire [9:0] bht_index = fetch_pc[11:2] ^ {{(10-GHR_WIDTH){1'b0}}, ghr};
    wire [1:0] bht_state = bht[bht_index];
    wire gshare_dir = (bht_state >= 2'b10);

    wire [4:0] set_idx = fetch_pc[6:2];
    wire hit0 = btb_valid[0][set_idx] && (btb_tag[0][set_idx] == fetch_pc);
    wire hit1 = btb_valid[1][set_idx] && (btb_tag[1][set_idx] == fetch_pc);
    wire btb_hit = hit0 || hit1;

    wire [31:0] btb_target_out = hit0 ? btb_target[0][set_idx] : btb_target[1][set_idx];
    wire [1:0]  btb_type_out   = hit0 ? btb_type[0][set_idx]   : btb_type[1][set_idx];

    wire [31:0] ras_top = (ras_ptr > 0) ? ras_stack[ras_ptr - 1'b1] : 32'b0;

    assign pred_taken  = fetch_valid && btb_hit && ((btb_type_out == 2'b10) || gshare_dir);
    assign pred_target = (btb_type_out == 2'b10) ? ras_top : btb_target_out;
    assign pred_info   = {ghr, bht_index, ras_ptr};

    wire [RAS_PTR_WIDTH-1:0] old_ras_ptr    = old_pred_info[RAS_PTR_WIDTH-1 : 0];
    wire [9:0]               update_bht_idx = old_pred_info[RAS_PTR_WIDTH+9 : RAS_PTR_WIDTH];
    wire [GHR_WIDTH-1:0]     old_ghr_val    = old_pred_info[GHR_WIDTH+RAS_PTR_WIDTH+9 : RAS_PTR_WIDTH+10];

    wire [4:0] update_set_idx = update_pc[6:2];
    wire update_hit0 = btb_valid[0][update_set_idx] && (btb_tag[0][update_set_idx] == update_pc);
    wire update_hit1 = btb_valid[1][update_set_idx] && (btb_tag[1][update_set_idx] == update_pc);

    // ============================================================
    // 4. 时序更新逻辑 (已移除大数组的重置循环)
    // ============================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            // 仅重置必要的指针和关键控制寄存器
            ghr     <= {GHR_WIDTH{1'b0}};
            ras_ptr <= {RAS_PTR_WIDTH{1'b0}};
            // 注：bht, btb_valid 等大数组不再此进行 for 循环复位
        end else begin
            // A. GHR 与 RAS ptr 纠正
            if (flush || mispredict) begin
                ghr     <= {old_ghr_val[GHR_WIDTH-2:0], actual_taken};
                ras_ptr <= old_ras_ptr;
            end else if (fetch_valid && !stall) begin
                ghr <= {ghr[GHR_WIDTH-2:0], pred_taken};
            end

            // B. BHT 更新
            if (update_en) begin
                if (actual_taken) begin
                    if (bht[update_bht_idx] != 2'b11)
                        bht[update_bht_idx] <= bht[update_bht_idx] + 2'b01;
                end else begin
                    if (bht[update_bht_idx] != 2'b00)
                        bht[update_bht_idx] <= bht[update_bht_idx] - 2'b01;
                end
            end

            // C. BTB 更新
            if (update_en && actual_taken) begin
                if (update_hit0) begin
                    btb_target[0][update_set_idx] <= actual_target;
                    btb_lru[update_set_idx]        <= 1'b1;
                end else if (update_hit1) begin
                    btb_target[1][update_set_idx] <= actual_target;
                    btb_lru[update_set_idx]        <= 1'b0;
                end else begin
                    if (btb_lru[update_set_idx] == 1'b0) begin
                        btb_tag[0][update_set_idx]    <= update_pc;
                        btb_target[0][update_set_idx] <= actual_target;
                        btb_type[0][update_set_idx]   <= branch_type;
                        btb_valid[0][update_set_idx]  <= 1'b1;
                        btb_lru[update_set_idx]        <= 1'b1;
                    end else begin
                        btb_tag[1][update_set_idx]    <= update_pc;
                        btb_target[1][update_set_idx] <= actual_target;
                        btb_type[1][update_set_idx]   <= branch_type;
                        btb_valid[1][update_set_idx]  <= 1'b1;
                        btb_lru[update_set_idx]        <= 1'b0;
                    end
                end
            end

            // D. RAS 推测压栈/弹栈
            if (fetch_valid && !stall && btb_hit && !(flush || mispredict)) begin
                if (btb_type_out == 2'b01) begin
                    if (ras_ptr < RAS_SIZE) begin
                        ras_stack[ras_ptr] <= fetch_pc + 32'd4;
                        ras_ptr            <= ras_ptr + 1'b1;
                    end
                end else if (btb_type_out == 2'b10) begin
                    if (ras_ptr > 0)
                        ras_ptr <= ras_ptr - 1'b1;
                end
            end
        end
    end

endmodule
