module csr (
    input   wire            clk,
    input   wire            rst_n,
    input   wire            retired,        // instruction retired in WB
    input   wire    [11:0]  csr_rd_addr,    // CSR read address from EX
    output  wire    [31:0]  csr_rd_data     // CSR read data to EX
);
    reg [63:0] mcycle;
    reg [63:0] minstret;

    always @(posedge clk) begin
        if (!rst_n) begin
            mcycle   <= 64'b0;
            minstret <= 64'b0;
        end else begin
            mcycle   <= mcycle + 64'd1;
            if (retired)
                minstret <= minstret + 64'd1;
        end
    end

    reg [31:0] rdata;
    always @(*) begin
        case (csr_rd_addr)
            12'hB00: rdata = mcycle[31:0];
            12'hB80: rdata = mcycle[63:32];
            12'hB02: rdata = minstret[31:0];
            12'hB82: rdata = minstret[63:32];
            default:  rdata = 32'b0;
        endcase
    end
    assign csr_rd_data = rdata;

endmodule
