module fpga_top(
    input sys_clk,
    input sys_rst_n,
    output uart_tx 
);

    // 1. 内部定义连线 (这些不需要管脚分配！)
    wire [31:0] inst;
    wire [31:0] pc;
    
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
        .data2cpu_gnt       (data2cpu_gnt),
        .data2cpu_rdata     (data2cpu_rdata),
        .data2cpu_valid     (data2cpu_valid),
        .int2cpu_ext        (1'b0),
        .int2cpu_tmr        (1'b0),
        .int2cpu_sft        (1'b0)
    );

    blk_mem_gen_v_shared u_shared_mem (
    // Port A: 专门负责给 CPU 喂指令 (Instruction Bus)
    .clka  (sys_clk),
    .ena   (1'b1),               // 取指通常一直使能
    .wea   (1'b0),               // A口永远不写，只读指令
    .addra (cpu2instr_addr),    // 来自 CPU 的 PC (程序计数器)
    .douta (instr2cpu_rdata),      // 输出给 CPU 的指令寄存器内容

    // Port B: 专门负责 CPU 的 Load/Store (Data Bus)
    .clkb  (sys_clk),
    .enb   (mem_en),             // 来自 CPU 的访存使能 (valid)
    .web   (mem_we),             // 来自 CPU 的写使能
    .addrb (cpu2data_addr),     // 来自 CPU 的数据地址
    .dinb  (cpu2data_wdata),        // CPU 要写入的数据
    .doutb (data2cpu_rdata)        // CPU 读取的数据
);

endmodule
