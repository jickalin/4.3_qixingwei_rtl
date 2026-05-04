module axi_lite_cont #(
    parameter MEM_SIZE_KB   = 128,
    parameter DATA_WIDTH    = 32,
    parameter ADDR_WIDTH    = 32,
    parameter MEM_DEPTH     = (128 * 1024) / 4,
    parameter BRAM_ADDR_W   = $clog2(MEM_DEPTH)
) (
    input  wire        clk,
    input  wire        rst_n,

    // AW
    input  wire [31:0] s_axi_awaddr,
    input  wire [2:0]  s_axi_awprot,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,

    // write
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,

    // write response
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,

    // AR
    input  wire [31:0] s_axi_araddr,
    input  wire [2:0]  s_axi_arprot,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,

    // R
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,

    // Native BRAM Interface
    output wire        bram_en,
    output wire [3:0]  bram_we,
    output wire [BRAM_ADDR_W-1:0] bram_addr,
    output wire [31:0] bram_wdata,
    input  wire [31:0] bram_rdata
);

    // BRAM is Ready
    assign s_axi_awready = 1'b1;
    assign s_axi_wready  = 1'b1;
    assign s_axi_arready = 1'b1;

    // reback OKAY
    assign s_axi_bresp = 2'b00;
    assign s_axi_rresp = 2'b00;

    // bram_en 需保持 2 周期: 1 拍锁地址 + 1 拍驱动数据输出
    reg ar_active;
    always @(posedge clk) begin
        if (!rst_n)
            ar_active <= 1'b0;
        else if (s_axi_arvalid)
            ar_active <= 1'b1;
        else
            ar_active <= 1'b0;
    end

    assign bram_en   = ar_active || s_axi_arvalid || (s_axi_awvalid && s_axi_wvalid);
    assign bram_we   = (s_axi_awvalid && s_axi_wvalid) ? s_axi_wstrb : 4'b0000;
    assign bram_addr = s_axi_arvalid ? s_axi_araddr[BRAM_ADDR_W+1:2] : s_axi_awaddr[BRAM_ADDR_W+1:2];
    assign bram_wdata = s_axi_wdata;

    // BRAM 1T latency: data appears next cycle, captured here
    reg rvalid_reg;
    always @(posedge clk) begin
        if (!rst_n) rvalid_reg <= 1'b0;
        else rvalid_reg <= s_axi_arvalid && s_axi_arready;
    end
    assign s_axi_rvalid = rvalid_reg;
    assign s_axi_rdata  = bram_rdata;

    // write response
    reg bvalid_reg;
    always @(posedge clk) begin
        if (!rst_n) bvalid_reg <= 1'b0;
        else if (s_axi_awvalid && s_axi_wvalid) bvalid_reg <= 1'b1;
        else if (s_axi_bready) bvalid_reg <= 1'b0;
    end
    assign s_axi_bvalid = bvalid_reg;

endmodule
