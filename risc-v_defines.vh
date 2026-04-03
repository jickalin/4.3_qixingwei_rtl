







// riscv_defines.vh

// --- Opcode 定义 ---
`define OP_LUI      7'b0110111
`define OP_AUIPC    7'b0010111
`define OP_JAL      7'b1101111
`define OP_JALR     7'B1100111
`define OP_BRANCH   7'b1100011
`define OP_LOAD     7'b0000011
`define OP_STORE    7'b0100011
`define OP_ARITH_I  7'b0010011  // ADDI, SLTI 等
`define OP_ARITH_R  7'b0110011  // ADD, SUB 等


`define ALU_ADD  4'b0000
`define ALU_SUB  4'b0001
`define ALU_SLL  4'b0010  // 逻辑左移
`define ALU_SRL  4'b0011  // 逻辑右移
`define ALU_SRA  4'b0100  // 算术右移
`define ALU_AND  4'b0101
`define ALU_OR   4'b0110
`define ALU_XOR  4'b0111
`define ALU_SLT  4'b1000  // 有符号比较置位 (Set Less Than)
`define ALU_SLTU 4'b1001  // 无符号比较置位
