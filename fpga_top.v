module fpga_top(
    input sys_clk,
    input sys_rst_n,
    output uart_tx 
);
    reg             rst_n_r1, rst_n_r2;

always @(posedge sys_clk) begin
    rst_n_r1 <= sys_rst_n; // 打两拍消除亚稳态
    rst_n_r2 <= rst_n_r1;   
end
//  cpu 那一侧的信号定义
    wire    [31:0]      m_axi_instr_araddr;
    wire                m_axi_instr_arvalid;
    wire    [2:0]       m_axi_instr_arprot;
    wire                m_axi_instr_arready;
    // Read Data Channel
    wire    [31:0]      m_axi_instr_rdata;
    wire    [1:0]       m_axi_instr_rresp;
    wire                m_axi_instr_rvalid;
    wire                m_axi_instr_rready;

   // Write Address Channel
    wire    [31:0]      m_axi_data_awaddr;
    wire    [2:0]       m_axi_data_awprot;
    wire                m_axi_data_awvalid;
    wire                m_axi_data_awready;
    // Write Data Channel
    wire    [31:0]      m_axi_data_wdata;
    wire    [3:0]       m_axi_data_wstrb;
    wire                m_axi_data_wvalid;
    wire                m_axi_data_wready;
    // Write Response Channel
    wire    [1:0]       m_axi_data_bresp;
    wire                m_axi_data_bvalid;
    wire                m_axi_data_bready;
    // Read Address Channel
    wire    [31:0]      m_axi_data_araddr;
    wire                m_axi_data_arvalid;
    wire    [2:0]       m_axi_data_arprot;
    wire                m_axi_data_arready;
    // Read Data Channel
    wire    [31:0]      m_axi_data_rdata;
    wire    [1:0]       m_axi_data_rresp;
    wire                m_axi_data_rvalid;
    wire                m_axi_data_rready;
    // intr
    wire                int2cpu_ext;         
    wire                int2cpu_tmr;         
    wire                int2cpu_sft;

// ============================================================
// m0: BRAM Bridge (双口)
// ============================================================

// Port A Instruction Bus
wire    [31:0]      m0_axi_instr_araddr;
wire    [2:0]       m0_axi_instr_arprot;  
wire                m0_axi_instr_arvalid;
wire                m0_axi_instr_arready;
wire    [31:0]      m0_axi_instr_rdata;
wire    [1:0]       m0_axi_instr_rresp;
wire                m0_axi_instr_rvalid;
wire                m0_axi_instr_rready;

// Port B -data
wire    [31:0]      m0_axi_data_awaddr;
wire    [2:0]       m0_axi_data_awprot;
wire                m0_axi_data_awvalid;
wire                m0_axi_data_awready;
wire    [31:0]      m0_axi_data_wdata;
wire    [3:0]       m0_axi_data_wstrb;
wire                m0_axi_data_wvalid;
wire                m0_axi_data_wready;
wire    [1:0]       m0_axi_data_bresp;
wire                m0_axi_data_bvalid;
wire                m0_axi_data_bready;
wire    [31:0]      m0_axi_data_araddr;
wire    [2:0]       m0_axi_data_arprot;
wire                m0_axi_data_arvalid;
wire                m0_axi_data_arready;
wire    [31:0]      m0_axi_data_rdata;
wire    [1:0]       m0_axi_data_rresp;
wire                m0_axi_data_rvalid;
wire                m0_axi_data_rready;    
//instration BRAM wire
    wire                instr_bram_en;
    wire    [3:0]       instr_bram_we;
    wire    [11:0]      instr_bram_addr;
    wire    [31:0]      instr_bram_wdata;
    wire    [31:0]      instr_bram_rdata;

    //data BRAM wire
    wire                data_bram_en;
    wire    [3:0]       data_bram_we;
    wire    [11:0]      data_bram_addr;
    wire    [31:0]      data_bram_wdata;
    wire    [31:0]      data_bram_rdata;



    assign  int2cpu_ext = 0;
    assign  int2cpu_tmr = 0;
    assign  int2cpu_sft = 0;
    //
     rv32i_core_top u_cpu (
        .clk                    (sys_clk),
        .rst_n                  (rst_n_r2),
    // instr read address channel
        .m_axi_instr_araddr     (m_axi_instr_araddr),
        .m_axi_instr_arvalid    (m_axi_instr_arvalid),
        .m_axi_instr_arprot     (m_axi_instr_arprot),
        .m_axi_instr_arready    (m_axi_instr_arready),
    // instr Read Data Channel
        .m_axi_instr_rdata      (m_axi_instr_rdata),
        .m_axi_instr_rresp      (m_axi_instr_rresp),
        .m_axi_instr_rvalid     (m_axi_instr_rvalid),
        .m_axi_instr_rready     (m_axi_instr_rready),
    // Write Address Channel
        .m_axi_data_awaddr      (m_axi_data_awaddr),
        .m_axi_data_awprot      (m_axi_data_awprot),
        .m_axi_data_awvalid     (m_axi_data_awvalid),
        .m_axi_data_awready     (m_axi_data_awready),
    // Write Data Channel
        .m_axi_data_wdata       (m_axi_data_wdata),
        .m_axi_data_wstrb       (m_axi_data_wstrb),
        .m_axi_data_wvalid      (m_axi_data_wvalid),
        .m_axi_data_wready      (m_axi_data_wready),
    // Write Response Channel
        .m_axi_data_bresp       (m_axi_data_bresp),
        .m_axi_data_bvalid      (m_axi_data_bvalid),
        .m_axi_data_bready      (m_axi_data_bready),
    // Read Address Channel
        .m_axi_data_araddr      (m_axi_data_araddr),
        .m_axi_data_arvalid     (m_axi_data_arvalid),
        .m_axi_data_arprot      (m_axi_data_arprot),
        .m_axi_data_arready     (m_axi_data_arready),
    // Read Data Channel
        .m_axi_data_rdata       (m_axi_data_rdata),
        .m_axi_data_rresp       (m_axi_data_rresp),
        .m_axi_data_rvalid      (m_axi_data_rvalid),
        .m_axi_data_rready      (m_axi_data_rready),

  
        .int2cpu_ext        (int2cpu_ext),
        .int2cpu_tmr        (int2cpu_tmr),
        .int2cpu_sft        (int2cpu_sft)
    );





    // BUS matrix

    bus_matrix u_bus_matrix (
    .clk              (sys_clk),
    .rst_n            (rst_n_r2),

    //CPU Slave Interfaces
    // 1. 指令总线 (仅读取)
    .s_axi_instr_araddr (m_axi_instr_araddr),
    .s_axi_instr_arprot (m_axi_instr_arprot),
    .s_axi_instr_arvalid(m_axi_instr_arvalid),
    .s_axi_instr_arready(m_axi_instr_arready),
    .s_axi_instr_rdata  (m_axi_instr_rdata),
    .s_axi_instr_rresp  (m_axi_instr_rresp),
    .s_axi_instr_rvalid (m_axi_instr_rvalid),
    .s_axi_instr_rready (m_axi_instr_rready),

    // 2. 数据总线 (读写)
    .s_axi_data_awaddr  (m_axi_data_awaddr),
    .s_axi_data_awprot  (m_axi_data_awprot),
    .s_axi_data_awvalid (m_axi_data_awvalid),
    .s_axi_data_awready (m_axi_data_awready),
    .s_axi_data_wdata   (m_axi_data_wdata),
    .s_axi_data_wstrb   (m_axi_data_wstrb),
    .s_axi_data_wvalid  (m_axi_data_wvalid),
    .s_axi_data_wready  (m_axi_data_wready),
    .s_axi_data_bresp   (m_axi_data_bresp),
    .s_axi_data_bvalid  (m_axi_data_bvalid),
    .s_axi_data_bready  (m_axi_data_bready),
    .s_axi_data_araddr  (m_axi_data_araddr),
    .s_axi_data_arprot  (m_axi_data_arprot),
    .s_axi_data_arvalid (m_axi_data_arvalid),
    .s_axi_data_arready (m_axi_data_arready),
    .s_axi_data_rdata   (m_axi_data_rdata),
    .s_axi_data_rresp   (m_axi_data_rresp),
    .s_axi_data_rvalid  (m_axi_data_rvalid),
    .s_axi_data_rready  (m_axi_data_rready),

    // m0: BRAM Bridge connect to axi controller
    // Port A - instr
    .m0_axi_instr_araddr    (m0_axi_instr_araddr),
    .m0_axi_instr_arprot    (m0_axi_instr_arprot),  
    .m0_axi_instr_arvalid   (m0_axi_instr_arvalid),
    .m0_axi_instr_arready   (m0_axi_instr_arready),
    .m0_axi_instr_rdata     (m0_axi_instr_rdata),
    .m0_axi_instr_rresp     (m0_axi_instr_rresp),
    .m0_axi_instr_rvalid    (m0_axi_instr_rvalid),
    .m0_axi_instr_rready    (m0_axi_instr_rready),

      // Port B - 连接数据总线 (Data Bus)
    .m0_axi_data_awaddr     (m0_axi_data_awaddr),
    .m0_axi_data_awprot     (m0_axi_data_awprot),   
    .m0_axi_data_awvalid    (m0_axi_data_awvalid),
    .m0_axi_data_awready    (m0_axi_data_awready),
    .m0_axi_data_wdata      (m0_axi_data_wdata),
    .m0_axi_data_wstrb      (m0_axi_data_wstrb),
    .m0_axi_data_wvalid     (m0_axi_data_wvalid),
    .m0_axi_data_wready     (m0_axi_data_wready),
    .m0_axi_data_bresp      (m0_axi_data_bresp),
    .m0_axi_data_bvalid     (m0_axi_data_bvalid),
    .m0_axi_data_bready     (m0_axi_data_bready),
    .m0_axi_data_araddr     (m0_axi_data_araddr),
    .m0_axi_data_arprot     (m0_axi_data_arprot),
    .m0_axi_data_arvalid    (m0_axi_data_arvalid),
    .m0_axi_data_arready    (m0_axi_data_arready),
    .m0_axi_data_rdata      (m0_axi_data_rdata),
    .m0_axi_data_rresp      (m0_axi_data_rresp),
    .m0_axi_data_rvalid     (m0_axi_data_rvalid),
    .m0_axi_data_rready     (m0_axi_data_rready)
);



        // axi controller of isntr
       axi_lite_cont    u_axi_instr(
        .clk            (sys_clk),
        .rst_n          (rst_n_r2),

        // Write Address
        .s_axi_awaddr   (32'd0),     
        .s_axi_awprot   (3'd0),      
        .s_axi_awvalid  (1'd0),      
        .s_axi_awready  (),          

        // Write Data
        .s_axi_wdata    (32'd0),     
        .s_axi_wstrb    (4'd0),      
        .s_axi_wvalid   (1'd0),      
        .s_axi_wready   (),           

        // Write Response
        .s_axi_bresp    (),           
        .s_axi_bvalid   (),           
        .s_axi_bready   (1'd0),//master donot ready         

        // read address
        .s_axi_araddr   (m0_axi_instr_araddr),
        .s_axi_arprot   (m0_axi_instr_arprot),
        .s_axi_arvalid  (m0_axi_instr_arvalid),
        .s_axi_arready  (m0_axi_instr_arready),
        // read data
        .s_axi_rdata    (m0_axi_instr_rdata),
        .s_axi_rresp    (m0_axi_instr_rresp),
        .s_axi_rvalid   (m0_axi_instr_rvalid),
        .s_axi_rready   (m0_axi_instr_rready),

        // instr_BRAM
        .bram_en        (instr_bram_en),
        .bram_we        (instr_bram_we),
        .bram_addr      (instr_bram_addr),
        .bram_wdata     (instr_bram_wdata),
        .bram_rdata     (instr_bram_rdata)
    );

     // axi controller of data
    axi_lite_cont    u_axi_data(
        .clk            (sys_clk),
        .rst_n          (rst_n_r2),

        // Write Address
        .s_axi_awaddr   (m0_axi_data_awaddr),     
        .s_axi_awprot   (m0_axi_data_awprot),      
        .s_axi_awvalid  (m0_axi_data_awvalid),      
        .s_axi_awready  (m0_axi_data_awready),          

        // Write Data
        .s_axi_wdata    (m0_axi_data_wdata),     
        .s_axi_wstrb    (m0_axi_data_wstrb),      
        .s_axi_wvalid   (m0_axi_data_wvalid),      
        .s_axi_wready   (m0_axi_data_wready),           

        // Write Response
        .s_axi_bresp    (m0_axi_data_bresp),           
        .s_axi_bvalid   (m0_axi_data_bvalid),           
        .s_axi_bready   (m0_axi_data_bready),        

        // read address
        .s_axi_araddr   (m0_axi_data_araddr),
        .s_axi_arprot   (m0_axi_data_arprot),
        .s_axi_arvalid  (m0_axi_data_arvalid),
        .s_axi_arready  (m0_axi_data_arready),
        // read data
        .s_axi_rdata    (m0_axi_data_rdata),
        .s_axi_rresp    (m0_axi_data_rresp),
        .s_axi_rvalid   (m0_axi_data_rvalid),
        .s_axi_rready   (m0_axi_data_rready),

        // instr_BRAM
        .bram_en        (data_bram_en),
        .bram_we        (data_bram_we),
        .bram_addr      (data_bram_addr),
        .bram_wdata     (data_bram_wdata),
        .bram_rdata     (data_bram_rdata)
    );







   // wire                data_en;
   // assign  data_en = (cpu2data_we | cpu2data_rd | cpu2data_req );//why req is must req just is ready_en


    blk_mem_gen_0 u_shared_mem (  //2 ports instr and data
    .clka  (sys_clk),
    .ena   (instr_bram_en),//enable               
    .wea   (4'b0), //write_enable              
    .addra (instr_bram_addr),
    .dina  (32'b0),      //no input at instr port
    .douta (instr_bram_rdata),   

    
    .clkb  (sys_clk),
    .enb   (data_bram_en),             //CPU  (valid)
    .web   (data_bram_we),  //write bit enable
    .addrb (data_bram_addr),     
    .dinb  (data_bram_wdata),    
    .doutb (data_bram_rdata)     
);


//always @ (posedge sys_clk ) begin
  //  if(!rst_n_r2) begin
    //instr2cpu_valid <= 0;
    //data2cpu_gnt    <= 0;

//end    else begin
//    instr2cpu_valid <= cpu2instr_req;
//    data2cpu_gnt    <= cpu2data_req;
//end
//end
//assign data2cpu_valid = data2cpu_gnt;
assign uart_tx = data_bram_rdata[12];


endmodule
