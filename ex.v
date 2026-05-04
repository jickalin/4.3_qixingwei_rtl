`include "risc-v_defines.vh"


module ex_stage (
    input   wire            clk,
    input   wire            rst_n,
    input   wire    [4:0]   ex_alu_op,
    input   wire    [31:0]  ex_alu_rs1,
    input   wire    [31:0]  ex_alu_rs2,
    input   wire    [31:0]  ex_alu_imm,
    input   wire    [1:0]   ex_a_sel,
    input   wire    [1:0]   ex_b_sel,
    input   wire            ex_rs1_use,
    input   wire            ex_rs2_use,
    input   wire    [2:0]   ex_funct3,
    input   wire            ex_jal,
    input   wire            ex_branch_en,
    input   wire            ex_jump_r,
    input   wire    [31:0]  ex_pc,
    input   wire            ex_pred_taken,
    input   wire    [31:0]  ex_pred_target,

    output  wire            update_en,
    output  wire            actual_taken,
    output  wire            mispredict,
    output  wire    [31:0]  ex_recover_pc,

    input   wire    [1:0]   mem_forward_en,
    input   wire    [1:0]   wb_forward_en,
    input   wire    [31:0]  mem_forward_data,
    input   wire    [31:0]  wb_forward_data,

    output  reg     [31:0]  alu_result_o,
    output  reg     [31:0]  branch_or_jump_pc,
    output  reg     [31:0]  ex_mem_wdata,
    output  wire    [3:0]   ex_be,

    input   wire            ex_csr_read_en,
    input   wire    [11:0]  ex_csr_addr,
    input   wire    [31:0]  csr_rdata,

    output  wire            div_stall
);
    wire            branch_taken;
    reg     [31:0]  updated_rs1;
    reg     [31:0]  updated_rs2;
    wire            alu_zero_o;

    // forwarding
    always @(*) begin
        updated_rs1 = ex_alu_rs1;
        if(ex_rs1_use)begin
        if(mem_forward_en[1])
            updated_rs1 = mem_forward_data;
        else if(wb_forward_en[1])
            updated_rs1 = wb_forward_data;
        end
    end
    always @(*) begin
        updated_rs2 = ex_alu_rs2;
        if(ex_rs2_use) begin
        if(mem_forward_en[0])
            updated_rs2 = mem_forward_data;
        else if(wb_forward_en[0])
            updated_rs2 = wb_forward_data;
        end
    end

    reg     [31:0]  alu_src1_i;
    reg     [31:0]  alu_src2_i;
    always @(*) begin
        case (ex_a_sel)
            2'b00:   alu_src1_i   = updated_rs1;
            2'b01:   alu_src1_i   = ex_pc;
            2'b10:   alu_src1_i   = 32'b0;
            default: alu_src1_i   = updated_rs1;
        endcase
    end

    always @(*) begin
        case (ex_b_sel)
            2'b00:   alu_src2_i   = updated_rs2;
            2'b01:   alu_src2_i   = ex_alu_imm;
            2'b10:   alu_src2_i   = 32'd4;
            default: alu_src2_i   = updated_rs2;
        endcase
    end

    // ============================================================
    // Multiplier (single-cycle, DSP-inferred)
    // ============================================================
    wire signed [63:0] mul_ss = $signed({{32{alu_src1_i[31]}}, alu_src1_i}) *
                                $signed({{32{alu_src2_i[31]}}, alu_src2_i});
    wire [63:0] mul_su = $signed({{32{alu_src1_i[31]}}, alu_src1_i}) *
                                {32'b0, alu_src2_i};
    wire [63:0] mul_uu = {32'b0, alu_src1_i} * {32'b0, alu_src2_i};

    // ============================================================
    // Divider state machine (multi-cycle, restoring algorithm)
    // ============================================================
    reg        div_active;
    reg [5:0]  div_cycle;
    reg [31:0] div_rem;
    reg [31:0] div_quot;
    reg [31:0] div_divisor;
    reg        div_is_signed;
    reg        div_is_rem;
    reg        div_dividend_sign;
    reg        div_divisor_sign;
    reg        div_by_zero;
    reg        div_signed_overflow;
    reg [31:0] div_orig_dividend;

    wire is_div_op = (ex_alu_op == `ALU_DIV)  || (ex_alu_op == `ALU_DIVU) ||
                     (ex_alu_op == `ALU_REM)  || (ex_alu_op == `ALU_REMU);
    wire div_start = is_div_op && !div_active;

    wire [31:0] R_shifted = {div_rem[30:0], div_quot[31]};
    wire [31:0] R_sub     = R_shifted - div_divisor;
    wire        R_ge_D    = ~R_sub[31];

    always @(posedge clk) begin
        if (!rst_n) begin
            div_active  <= 1'b0;
            div_cycle   <= 6'b0;
        end else if (div_start) begin
            div_active        <= 1'b1;
            div_cycle         <= 6'b0;
            div_is_signed     <= (ex_alu_op == `ALU_DIV) || (ex_alu_op == `ALU_REM);
            div_is_rem        <= (ex_alu_op == `ALU_REM) || (ex_alu_op == `ALU_REMU);
            div_dividend_sign <= updated_rs1[31];
            div_divisor_sign  <= updated_rs2[31];
            div_orig_dividend <= updated_rs1;
            if (updated_rs2 == 32'b0) begin
                div_by_zero         <= 1'b1;
                div_signed_overflow <= 1'b0;
            end else if ((ex_alu_op == `ALU_DIV || ex_alu_op == `ALU_REM) &&
                         updated_rs1 == 32'h80000000 && updated_rs2 == 32'hFFFFFFFF) begin
                div_by_zero         <= 1'b0;
                div_signed_overflow <= 1'b1;
            end else begin
                div_by_zero         <= 1'b0;
                div_signed_overflow <= 1'b0;
                div_rem             <= 32'b0;
                div_quot            <= ((ex_alu_op == `ALU_DIV || ex_alu_op == `ALU_REM) && updated_rs1[31])
                                      ? -updated_rs1 : updated_rs1;
                div_divisor         <= ((ex_alu_op == `ALU_DIV || ex_alu_op == `ALU_REM) && updated_rs2[31])
                                      ? -updated_rs2 : updated_rs2;
            end
        end else if (div_active) begin
            if (div_by_zero || div_signed_overflow) begin
                div_active <= 1'b0;
            end else if (div_cycle < 6'd32) begin
                div_rem  <= R_ge_D ? R_sub : R_shifted;
                div_quot <= {div_quot[30:0], R_ge_D};
                div_cycle <= div_cycle + 6'd1;
                if (div_cycle == 6'd31) div_active <= 1'b0;
            end
        end
    end

    assign div_stall = div_active || div_start;

    // Division result (combinational, valid when !div_stall)
    wire [31:0] div_result_unsigned;
    wire        div_result_sign_bit;
    assign div_result_unsigned = div_is_rem ? div_rem : div_quot;
    assign div_result_sign_bit = div_is_rem ? div_dividend_sign :
                                              (div_dividend_sign ^ div_divisor_sign);

    wire [31:0] div_result_normal = (div_is_signed && div_result_sign_bit) ?
                                    -div_result_unsigned : div_result_unsigned;
    wire [31:0] div_result = div_by_zero         ? (div_is_rem ? div_orig_dividend : 32'hFFFFFFFF) :
                             div_signed_overflow ? (div_is_rem ? 32'b0 : 32'h80000000) :
                             div_result_normal;

    // ============================================================
    // ALU result
    // ============================================================
    assign alu_zero_o = (alu_result_o == 32'b0);

    always @(*) begin
        if (ex_csr_read_en)
            alu_result_o = csr_rdata;
        else case (ex_alu_op)
            `ALU_ADD:  alu_result_o = alu_src1_i + alu_src2_i;
            `ALU_SUB:  alu_result_o = alu_src1_i - alu_src2_i;
            `ALU_AND:  alu_result_o = alu_src1_i & alu_src2_i;
            `ALU_OR:   alu_result_o = alu_src1_i | alu_src2_i;
            `ALU_XOR:  alu_result_o = alu_src1_i ^ alu_src2_i;
            `ALU_SLL:  alu_result_o = alu_src1_i << alu_src2_i[4:0];
            `ALU_SRL:  alu_result_o = alu_src1_i >> alu_src2_i[4:0];
            `ALU_SRA:  alu_result_o = $signed(alu_src1_i) >>> alu_src2_i[4:0];
            `ALU_SLT:  alu_result_o = ($signed(alu_src1_i) < $signed(alu_src2_i)) ? 32'd1 : 32'd0;
            `ALU_SLTU: alu_result_o = (alu_src1_i < alu_src2_i) ? 32'd1 : 32'd0;
            // RV32M
            `ALU_MUL:    alu_result_o = mul_ss[31:0];
            `ALU_MULH:   alu_result_o = mul_ss[63:32];
            `ALU_MULHSU: alu_result_o = mul_su[63:32];
            `ALU_MULHU:  alu_result_o = mul_uu[63:32];
            `ALU_DIV, `ALU_DIVU, `ALU_REM, `ALU_REMU:
                         alu_result_o = div_result;
            default:     alu_result_o = 32'b0;
        endcase
    end

    assign branch_taken = ex_jump_r ||
        ex_branch_en && (
       (ex_funct3 == 3'b000 && alu_zero_o)     ||
       (ex_funct3 == 3'b001 && !alu_zero_o)    ||
       (ex_funct3 == 3'b100 && alu_result_o[0])||
       (ex_funct3 == 3'b101 && !alu_result_o[0])||
       (ex_funct3 == 3'b110 && alu_result_o[0])||
       (ex_funct3 == 3'b111 && !alu_result_o[0])
       );

    always @(*) begin
        branch_or_jump_pc = 32'b0;
        if(ex_jump_r)
            branch_or_jump_pc = (updated_rs1 + ex_alu_imm) & 32'hFFFFFFFE;
        else if(ex_branch_en | ex_jal)
            branch_or_jump_pc = (ex_pc + ex_alu_imm) & 32'hFFFFFFFE;
    end

    // 1T pre to write in mem data
    always @(*) begin
        case (ex_funct3[1:0])
            2'b00: ex_mem_wdata = {4{updated_rs2[7:0]}};
            2'b01: ex_mem_wdata = {2{updated_rs2[15:0]}};
            2'b10: ex_mem_wdata = updated_rs2;
            default: ex_mem_wdata = updated_rs2;
        endcase
    end
    wire [1:0] addr_offset = alu_result_o[1:0];
    assign ex_be = (ex_funct3[1:0] == 2'b00) ? (4'b0001 << addr_offset) :
                   (ex_funct3[1:0] == 2'b01) ? (4'b0011 << {addr_offset[1], 1'b0}) :
                   (ex_funct3[1:0] == 2'b10) ? 4'b1111 :
                                                4'b0000;

    // BPU info
    assign update_en     = ex_branch_en || ex_jump_r || ex_jal;
    assign actual_taken  = (ex_branch_en && branch_taken) || ex_jal || ex_jump_r;
    assign mispredict    = (actual_taken != ex_pred_taken) ||
                           (actual_taken && (branch_or_jump_pc != ex_pred_target));
    assign ex_recover_pc = actual_taken ? branch_or_jump_pc : (ex_pc + 4);
endmodule
