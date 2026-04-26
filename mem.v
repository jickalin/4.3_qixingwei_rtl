module mem_stage (
    input   wire            mem_mem_write_en,
    input   wire            mem_mem_read_en,
    input   wire    [2:0]   mem_funct3,      
    input   wire    [31:0]  mem_alu_result,  
    input   wire    [31:0]  mem_updated_rs2, 

    input   wire    [31:0]  dmem_rdata,      
    input   wire            dmem_gnt,  //1T ignore it      
    input   wire            dmem_valid,
    output  wire            dmem_req, //ignore it
    output  wire            mem_write_en,// to data mem
    output  wire            mem_read_en,
    output  wire    [31:0]  dmem_addr,//to data mem
    output  wire    [3:0]   dmem_be,
    output  reg     [31:0]  dmem_wdata,

    output  reg     [31:0]  mem_load_data,//to wb    
    output  wire            mem_ready   //stall to hazard     
);
    assign  dmem_req    = 1'b1;
    assign dmem_addr    = mem_alu_result;
    assign mem_write_en = mem_mem_write_en;
    assign mem_read_en  = mem_mem_read_en;

    wire [1:0] addr_offset = mem_alu_result[1:0];

    always @(*) begin
        case (mem_funct3[1:0])
            2'b00: 
                dmem_wdata = {4{mem_updated_rs2[7:0]}};
            2'b01: 
                dmem_wdata = {2{mem_updated_rs2[15:0]}};
            2'b10: // SW
                dmem_wdata = mem_updated_rs2;
            default: 
                dmem_wdata = mem_updated_rs2;
        endcase
    end

    assign dmem_be = (mem_funct3[1:0] == 2'b00) ? (4'b0001 << addr_offset) :      // Byte
                     (mem_funct3[1:0] == 2'b01) ? (4'b0011 << {addr_offset[1], 1'b0}) : // Half 
                     (mem_funct3[1:0] == 2'b10) ? 4'b1111 :                       // Word
                                                  4'b0000;

    always @(*) begin
        mem_load_data = 32'b0;
        if (mem_mem_read_en) begin
            case (mem_funct3)
                3'b000: // LB
                    case (addr_offset)
                        2'b00: mem_load_data = {{24{dmem_rdata[7]}},  dmem_rdata[7:0]};
                        2'b01: mem_load_data = {{24{dmem_rdata[15]}}, dmem_rdata[15:8]};
                        2'b10: mem_load_data = {{24{dmem_rdata[23]}}, dmem_rdata[23:16]};
                        2'b11: mem_load_data = {{24{dmem_rdata[31]}}, dmem_rdata[31:24]};
                    endcase
                3'b001: // LH
                    case (addr_offset[1])
                        1'b0:  mem_load_data = {{16{dmem_rdata[15]}}, dmem_rdata[15:0]};
                        1'b1:  mem_load_data = {{16{dmem_rdata[31]}}, dmem_rdata[31:16]};
                    endcase
                3'b010: // LW
                    mem_load_data = dmem_rdata;
                3'b100: // LBU
                    case (addr_offset)
                        2'b00: mem_load_data = {24'b0, dmem_rdata[7:0]};
                        2'b01: mem_load_data = {24'b0, dmem_rdata[15:8]};
                        2'b10: mem_load_data = {24'b0, dmem_rdata[23:16]};
                        2'b11: mem_load_data = {24'b0, dmem_rdata[31:24]};
                    endcase
                3'b101: // LHU
                    case (addr_offset[1])
                        1'b0:  mem_load_data = {16'b0, dmem_rdata[15:0]};
                        1'b1:  mem_load_data = {16'b0, dmem_rdata[31:16]};
                    endcase
                default: mem_load_data = dmem_rdata;
            endcase
        end
    end


    assign mem_ready = (mem_mem_read_en || mem_mem_write_en) ? (dmem_valid) : 1'b1;

endmodule
