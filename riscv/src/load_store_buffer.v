`include "utils.v"

`define IDLE 3'b000
`define LOAD 3'b001
`define STORE 3'b010
`define ROLLBACK 2'b11

`define WRITE 1'b0
`define READ 1'b1

module LSB(
    input  wire clk,
    input  wire rst,
    input  wire rdy,

    output wire lsb_full,

    input  wire commit_command_from_rob,
    input  wire [`ROB_RANGE] alias_to_store,
    
    input  wire rollback_from_rob,

    input  wire valid_from_disp,
    input  wire [`DATA_RANGE] pc_from_disp,
    input  wire [6:0] inst_type_from_disp,
    input  wire [`ROB_RANGE] rd_from_disp,
    input  wire [`ROB_RANGE] Qi_from_disp,
    input  wire [`ROB_RANGE] Qj_from_disp,
    input  wire [`DATA_RANGE] Vi_from_disp,
    input  wire [`DATA_RANGE] Vj_from_disp,
    input  wire [`DATA_RANGE] imm_from_disp,

    input  wire valid_from_memctrl,
    input  wire [`DATA_RANGE] data_from_memctrl,
    output reg  valid_to_memctrl,
    
    output reg  [6:0] inst_type_to_memctrl,
    output reg  [`ADDR_RANGE] addr_to_memctrl,
    output reg  [`DATA_RANGE] data_to_memctrl,

    input  wire valid_from_alu,
    input  wire [`ROB_RANGE] alias_from_alu,
    input  wire [`DATA_RANGE] result_from_alu,

    output reg  valid_to_rob,
    output reg [`ROB_RANGE] alias_to_rob,
    output reg [`DATA_RANGE] result_to_rob
);
    reg write_or_read; // write = 0, read = 1

endmodule