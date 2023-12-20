`include "utils.v"

// 0 号位置不要存东西，不然怎么表示没有依赖！

module ROB(
    input  wire clk,
    input  wire rst,
    input  wire rdy,

    output wire rob_full,
    output wire rollback,
    output reg  [`DATA_RANGE] rollback_pc,

    input  wire valid_from_lsb,
    input  wire [`ROB_RANGE] alias_from_lsb,
    input  wire [`DATA_RANGE] result_from_lsb,

    output reg  commit_command_to_lsb,
    output reg  [`ROB_RANGE] alias_to_store,

    input  wire valid_from_alu,
    input  wire [`ROB_RANGE] alias_from_alu,
    input  wire [`DATA_RANGE] result_from_alu,

    input  wire really_jump_from_alu,
    input  wire [`DATA_RANGE] real_pc_from_alu,

    output reg  valid_to_predictor,
    output reg  really_jump_to_predictor,
    output reg  [`DATA_RANGE] real_pc_to_predictor,

    input  wire valid_from_disp,
    input  wire [`DATA_RANGE] pc_from_disp,
    input  wire [`REG_RANGE] rd_from_disp,
    input  wire is_jump_from_disp,
    input  wire predicted_jump_from_disp,
    input  wire [`OPT_RANGE] optype_from_disp,

    input  wire [`ROB_RANGE] Qi_from_disp,
    input  wire [`ROB_RANGE] Qj_from_disp,
    output wire Vi_valid_to_disp,
    output wire [`DATA_RANGE] Vi_to_disp,
    output wire Vj_valid_to_disp,
    output wire [`DATA_RANGE] Vj_to_disp,
    output wire [`ROB_RANGE] cur_rename_id_to_disp,

    output reg  valid_to_reg_file,
    output reg  [`REG_RANGE] reg_id_to_reg_file,
    output reg  [`ROB_RANGE] alias_to_reg_file,
    output reg  [`DATA_RANGE] result_to_reg_file
);

endmodule