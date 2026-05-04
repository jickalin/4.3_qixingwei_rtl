module uart_tx #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 115200
)(
    input   wire            clk,
    input   wire            rst_n,
    input   wire    [7:0]   tx_data,
    input   wire            tx_valid,
    output  wire            tx_busy,
    output  reg             tx
);
    localparam BIT_CNT_MAX = CLK_FREQ / BAUD_RATE;
    localparam CNT_W       = $clog2(BIT_CNT_MAX);

    reg  [3:0]  state;
    reg  [3:0]  next_state;
    reg  [CNT_W-1:0] bit_cnt;
    reg  [7:0]  shift_reg;

    localparam S_IDLE  = 4'd0;
    localparam S_START = 4'd1;
    localparam S_BIT0  = 4'd2;
    localparam S_BIT1  = 4'd3;
    localparam S_BIT2  = 4'd4;
    localparam S_BIT3  = 4'd5;
    localparam S_BIT4  = 4'd6;
    localparam S_BIT5  = 4'd7;
    localparam S_BIT6  = 4'd8;
    localparam S_BIT7  = 4'd9;
    localparam S_STOP  = 4'd10;

    assign tx_busy = (state != S_IDLE);

    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE:  if (tx_valid)              next_state = S_START;
            S_START: if (bit_cnt == BIT_CNT_MAX) next_state = S_BIT0;
            S_BIT0:  if (bit_cnt == BIT_CNT_MAX) next_state = S_BIT1;
            S_BIT1:  if (bit_cnt == BIT_CNT_MAX) next_state = S_BIT2;
            S_BIT2:  if (bit_cnt == BIT_CNT_MAX) next_state = S_BIT3;
            S_BIT3:  if (bit_cnt == BIT_CNT_MAX) next_state = S_BIT4;
            S_BIT4:  if (bit_cnt == BIT_CNT_MAX) next_state = S_BIT5;
            S_BIT5:  if (bit_cnt == BIT_CNT_MAX) next_state = S_BIT6;
            S_BIT6:  if (bit_cnt == BIT_CNT_MAX) next_state = S_BIT7;
            S_BIT7:  if (bit_cnt == BIT_CNT_MAX) next_state = S_STOP;
            S_STOP:  if (bit_cnt == BIT_CNT_MAX) next_state = S_IDLE;
            default: next_state = S_IDLE;
        endcase
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            bit_cnt  <= 0;
        end else begin
            if (state != next_state) begin
                state   <= next_state;
                bit_cnt <= 0;
            end else begin
                bit_cnt <= bit_cnt + 1;
            end
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            shift_reg <= 8'b0;
        end else if (state == S_IDLE && tx_valid) begin
            shift_reg <= tx_data;
        end else if (state == S_BIT0 && bit_cnt == BIT_CNT_MAX) begin
            shift_reg <= {1'b0, shift_reg[7:1]};
        end else if (state >= S_BIT1 && state <= S_BIT7 && bit_cnt == BIT_CNT_MAX) begin
            shift_reg <= {1'b0, shift_reg[7:1]};
        end
    end

    always @(*) begin
        case (state)
            S_IDLE, S_STOP: tx = 1'b1;
            S_START:        tx = 1'b0;
            default:        tx = shift_reg[0];
        endcase
    end

endmodule
