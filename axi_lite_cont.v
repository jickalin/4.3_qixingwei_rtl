module axi_lite_cont (
    input  wire        clk,
    input  wire        rst_n,

    // AW
    input  wire [31:0] s_axi_awaddr,//frome cpu 
    input  wire [2:0]  s_axi_awprot,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,// slave is ready to  receive date and sent to CPU 

    // write
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,// slave is ready to  receive date and sent to CPU 

    // write response
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,//cpu is ready to receive write response signs

    // AR
    input  wire [31:0] s_axi_araddr,
    input  wire [2:0]  s_axi_arprot,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,// slave is ready to  receive date and sent to CPU 

    // R
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,//cpu is ready to receive write response signs

    //  Native BRAM Interface (BRAM IP)
    output wire        bram_en,
    output wire [3:0]  bram_we,         //  wstrb
    output wire [11:0] bram_addr,
    output wire [31:0] bram_wdata,
    input  wire [31:0] bram_rdata
);

        
    // BRAM is Ready
    assign s_axi_awready = 1'b1;
    assign s_axi_wready  = 1'b1;
    assign s_axi_arready = 1'b1;

    // reback OKAY (00)
    assign s_axi_bresp = 2'b00;
    assign s_axi_rresp = 2'b00;

    // 
    assign bram_en   = s_axi_arvalid || (s_axi_awvalid && s_axi_wvalid);
    assign bram_we   = (s_axi_awvalid && s_axi_wvalid) ? s_axi_wstrb : 4'b0000;
    assign bram_addr = s_axi_arvalid ? s_axi_araddr[13:2] : s_axi_awaddr[13:2];
    assign bram_wdata = s_axi_wdata;

    // 读数据返回逻辑 (BRAM 通常 1 拍延迟)
    reg rvalid_reg;
    always @(posedge clk) begin
        if (!rst_n) rvalid_reg <= 1'b0;
        else rvalid_reg <= s_axi_arvalid && s_axi_arready;
    end
    assign s_axi_rvalid = rvalid_reg;
    assign s_axi_rdata  = bram_rdata;

    // 写响应返回逻辑
    reg bvalid_reg;
    always @(posedge clk) begin
        if (!rst_n) bvalid_reg <= 1'b0;
        else if (s_axi_awvalid && s_axi_wvalid) bvalid_reg <= 1'b1;
        else if (s_axi_bready) bvalid_reg <= 1'b0;
    end
    assign s_axi_bvalid = bvalid_reg;

endmodule




