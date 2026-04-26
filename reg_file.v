`include "risc-v_defines.vh"

module reg_file (
    input  wire        clk,
    input  wire        rst_n,
    
    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,
    output wire [31:0] rs1_data,
    output wire [31:0] rs2_data,
    

    input  wire [4:0]  rd_addr,
    input  wire        wr_en,
    input  wire [31:0] wr_data
);
    reg [31:0] rf [31:0];
    integer i;
    // write syn
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin           
            for (i = 0; i < 32; i = i + 1) begin
                rf[i] <= 32'b0;
            end
        end else if (wr_en && (rd_addr != 5'b0)) begin
            rf[rd_addr] <= wr_data;
        end
    end
    //read and forward reg hazard
    assign rs1_data = (rs1_addr == 5'b0) ? 32'b0 : 
                      ((rs1_addr == rd_addr) && wr_en) ? wr_data : rf[rs1_addr];

    assign rs2_data = (rs2_addr == 5'b0) ? 32'b0 : 
                      ((rs2_addr == rd_addr) && wr_en) ? wr_data : rf[rs2_addr];

endmodule
