module mem_stage (
    input   wire            mem_mem_write_en,
    input   wire            mem_mem_read_en,
    input   wire    [2:0]   mem_funct3,      
    input   wire    [1:0]   addr_offset,  
    input   wire    [31:0]  dmem_rdata,        
    input   wire            dmem_valid,
    


    output  reg     [31:0]  mem_load_data//to wb    
         
);
   

    always @(*) begin
        mem_load_data = 32'b0;
        if (mem_mem_read_en & dmem_valid) begin
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


    

endmodule
