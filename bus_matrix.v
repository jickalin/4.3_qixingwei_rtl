module bus_matrix (
    input  wire        clk,
    input  wire        rst_n,

    // ============================================================
    // CPU 侧接口 (Slave Interfaces)
    // ============================================================
    // 1. 指令总线 (仅读取)
    input  wire [31:0] s_axi_instr_araddr,
    input  wire [2:0]  s_axi_instr_arprot,
    input  wire        s_axi_instr_arvalid,
    output wire        s_axi_instr_arready,
    output wire [31:0] s_axi_instr_rdata,
    output wire [1:0]  s_axi_instr_rresp,
    output wire        s_axi_instr_rvalid,
    input  wire        s_axi_instr_rready,

    // 2. 数据总线 (读写)
    input  wire [31:0] s_axi_data_awaddr,
    input  wire [2:0]  s_axi_data_awprot,
    input  wire        s_axi_data_awvalid,
    output wire        s_axi_data_awready,
    input  wire [31:0] s_axi_data_wdata,
    input  wire [3:0]  s_axi_data_wstrb,
    input  wire        s_axi_data_wvalid,
    output wire        s_axi_data_wready,
    output wire [1:0]  s_axi_data_bresp,
    output wire        s_axi_data_bvalid,
    input  wire        s_axi_data_bready,
    input  wire [31:0] s_axi_data_araddr,
    input  wire [2:0]  s_axi_data_arprot,
    input  wire        s_axi_data_arvalid,
    output wire        s_axi_data_arready,
    output wire [31:0] s_axi_data_rdata,
    output wire [1:0]  s_axi_data_rresp,
    output wire        s_axi_data_rvalid,
    input  wire        s_axi_data_rready,

    // ============================================================
    // 设备侧接口 (Master Interfaces)
    // ============================================================
    // m0: BRAM Bridge (双口)
    // Port A - 连接指令总线
    output wire [31:0] m0_axi_instr_araddr,
    output wire [2:0]  m0_axi_instr_arprot,
    output wire        m0_axi_instr_arvalid,
    input  wire        m0_axi_instr_arready,
    input  wire [31:0] m0_axi_instr_rdata,
    input  wire [1:0]  m0_axi_instr_rresp,
    input  wire        m0_axi_instr_rvalid,
    output wire        m0_axi_instr_rready,

    // Port B - 连接数据总线
    output wire [31:0] m0_axi_data_awaddr,
    output wire [2:0]  m0_axi_data_awprot,
    output wire        m0_axi_data_awvalid,
    input  wire        m0_axi_data_awready,
    output wire [31:0] m0_axi_data_wdata,
    output wire [3:0]  m0_axi_data_wstrb,
    output wire        m0_axi_data_wvalid,
    input  wire        m0_axi_data_wready,
    input  wire [1:0]  m0_axi_data_bresp,
    input  wire        m0_axi_data_bvalid,
    output wire        m0_axi_data_bready,
    output wire [31:0] m0_axi_data_araddr,
    output wire [2:0]  m0_axi_data_arprot,
    output wire        m0_axi_data_arvalid,
    input  wire        m0_axi_data_arready,
    input  wire [31:0] m0_axi_data_rdata,
    input  wire [1:0]  m0_axi_data_rresp,
    input  wire        m0_axi_data_rvalid,
    output wire        m0_axi_data_rready,

    // m1: UART output (MMIO at 0x10000000, write-only)
    output wire [7:0]  m_uart_tx_data,
    output wire        m_uart_tx_valid,
    input  wire        m_uart_tx_busy

    //  Add other interface
);

    // ============================================================
    //指令端口接入点唯一，直接传递
    assign m0_axi_instr_araddr  = s_axi_instr_araddr;
    assign m0_axi_instr_arprot  = s_axi_instr_arprot;
    assign m0_axi_instr_arvalid = s_axi_instr_arvalid;
    assign s_axi_instr_arready  = m0_axi_instr_arready;

    assign s_axi_instr_rdata    = m0_axi_instr_rdata;
    assign s_axi_instr_rresp    = m0_axi_instr_rresp;
    assign s_axi_instr_rvalid   = m0_axi_instr_rvalid;
    assign m0_axi_instr_rready  = s_axi_instr_rready;


    // ============================================================
    // 数据总线地址译码 
    // ============================================================
    // BRAM 地址范围: 0x0000_0000 - 0x0000_3FFF (16KB )
    wire dec_is_bram_aw = (s_axi_data_awaddr[31:14] == 18'h0000);
    wire dec_is_bram_ar = (s_axi_data_araddr[31:14] == 18'h0000);

    // UART 地址: 0x10000000 (write-only)
    wire dec_is_uart_aw = (s_axi_data_awaddr[31:12] == 20'h10000);
    wire dec_is_uart_ar = (s_axi_data_araddr[31:12] == 20'h10000);

    // UART 写握手 (AW+W 同时到达)
    wire uart_wr_hsk = dec_is_uart_aw && s_axi_data_awvalid && s_axi_data_wvalid && !m_uart_tx_busy;

    // UART BVALID (写响应)
    reg uart_bvalid;
    always @(posedge clk) begin
        if (!rst_n)
            uart_bvalid <= 1'b0;
        else if (uart_wr_hsk)
            uart_bvalid <= 1'b1;
        else if (uart_bvalid && s_axi_data_bready)
            uart_bvalid <= 1'b0;
    end

    assign m_uart_tx_data  = s_axi_data_wdata[7:0];
    assign m_uart_tx_valid = uart_wr_hsk;
    


        // AW 通道
    assign m0_axi_data_awaddr  = s_axi_data_awaddr;
    assign m0_axi_data_awprot  = s_axi_data_awprot;
    assign m0_axi_data_awvalid = s_axi_data_awvalid && dec_is_bram_aw;
    
    // W 通道
    assign m0_axi_data_wdata   = s_axi_data_wdata;
    assign m0_axi_data_wstrb   = s_axi_data_wstrb;
    assign m0_axi_data_wvalid  = s_axi_data_wvalid && dec_is_bram_aw;

    // B 通道 (从从机回传)
    assign m0_axi_data_bready  = s_axi_data_bready;

    // CPU 侧的写握手和反馈
    assign s_axi_data_awready  = dec_is_bram_aw ? m0_axi_data_awready :
                                 dec_is_uart_aw ? !m_uart_tx_busy : 1'b0;
    assign s_axi_data_wready   = dec_is_bram_aw ? m0_axi_data_wready :
                                 dec_is_uart_aw ? !m_uart_tx_busy : 1'b0;
    assign s_axi_data_bvalid   = dec_is_bram_aw ? m0_axi_data_bvalid  : uart_bvalid;
    assign s_axi_data_bresp    = dec_is_bram_aw ? m0_axi_data_bresp   :
                                 uart_bvalid    ? 2'b00               : 2'b10;
    // AR 通道
    assign m0_axi_data_araddr  = s_axi_data_araddr;
    assign m0_axi_data_arprot  = s_axi_data_arprot;
    assign m0_axi_data_arvalid = s_axi_data_arvalid && dec_is_bram_ar;

    // R 通道 (从从机回传)
    assign m0_axi_data_rready  = s_axi_data_rready;

    // CPU 侧的读握手和反馈
    assign s_axi_data_arready  = dec_is_bram_ar ? m0_axi_data_arready : 1'b0;
    assign s_axi_data_rvalid   = m0_axi_data_rvalid;
    //assign s_axi_data_rdata    = bram_ar_reg    ? m0_axi_data_rdata   : 32'h0;
    assign s_axi_data_rdata    = m0_axi_data_rdata;//这两个读数据和有效信号晚1个周期，用当前的地址的得到的不准确，指令那一端因为一直在读也没有地址路由所以没有这个问题
    assign s_axi_data_rresp    = dec_is_bram_ar ? m0_axi_data_rresp   : 2'b10; // SLVERR

endmodule
