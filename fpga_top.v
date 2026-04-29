module fpga_top(
    input sys_clk,
    input sys_rst_n,
    output uart_tx 
);
    assign uart_tx = instr2cpu_rdata[12];
    //  instr wire
    wire    [31:0]  cpu2instr_addr;
    wire            cpu2instr_req;
    reg             instr2cpu_valid; //reg 
    wire    [31:0]  instr2cpu_rdata;

    //data mem wire
    wire    [31:0]  cpu2data_addr;
    wire    [31:0]  cpu2data_wdata;      
    wire            cpu2data_we;
    wire            cpu2data_rd;
    wire    [3:0]   cpu2data_be;        
    wire            cpu2data_req;
    wire            imem_stall;
    reg             data2cpu_gnt;        
    wire    [31:0]  data2cpu_rdata;      
    wire            data2cpu_valid;      

    // 中断接口
    wire            int2cpu_ext;         
    wire            int2cpu_tmr;         
    wire            int2cpu_sft;
    // 2. 实例化你的 CPU 核
     rv32i_core_top u_cpu (
        .clk                (sys_clk),
        .rst_n              (sys_rst_n),
        .cpu2instr_addr     (cpu2instr_addr),
        .cpu2instr_req      (cpu2instr_req),
        .instr2cpu_valid    (instr2cpu_valid),
        .instr2cpu_rdata    (instr2cpu_rdata),
        .cpu2data_addr      (cpu2data_addr),
        .cpu2data_wdata     (cpu2data_wdata),
        .cpu2data_we        (cpu2data_we),
        .cpu2data_rd        (cpu2data_rd),
        .cpu2data_be        (cpu2data_be),
        .cpu2data_req       (cpu2data_req),
        .imem_stall         (imem_stall),
        .data2cpu_gnt       (data2cpu_gnt),
        .data2cpu_rdata     (data2cpu_rdata),
        .data2cpu_valid     (data2cpu_valid),
        .int2cpu_ext        (1'b0),
        .int2cpu_tmr        (1'b0),
        .int2cpu_sft        (1'b0)
    );

    wire                data_en;
    assign  data_en = (cpu2data_we | cpu2data_rd |cpu2data_req);
    wire    [11:0]      ram_iaddr;
    wire    [11:0]      ram_daddr;

    assign  ram_iaddr   = cpu2instr_addr[13:2];
    assign  ram_daddr   = cpu2data_addr[13:2];

    blk_mem_gen_0 u_shared_mem (  //2 ports instr and data
    .clka  (sys_clk),
    .ena   (cpu2instr_req),//enable               
    .wea   (4'b0), //write_enable              
    .addra (ram_iaddr),
    .dina  (32'b0)      //no input at instr port
    .douta (instr2cpu_rdata),   

    
    .clkb  (sys_clk),
    .enb   (data_en),             //CPU  (valid)
    .web   (cpu2data_we ? cpu2data_be : 4'b0),  //write bit enable
    .addrb (ram_daddr),     
    .dinb  (cpu2data_wdata),    
    .doutb (data2cpu_rdata)     
);


always @ (posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
    instr2cpu_valid <= 0;
    data2cpu_gnt    <= 0;

end    else begin
    instr2cpu_valid <= cpu2instr_req;
    data2cpu_gnt    <= cpu2data_req;
end
end
assign data2cpu_valid = data2cpu_gnt;



endmodule
