`include "utils.v"

module dispatcher(
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire full,

    input wire rollback,

    // 从 decoder 接收信息
    output wire [`DATA_RANGE] data_to_decoder,
    input  wire [`OPT_RANGE] inst_type_from_decoder,
    input  wire [`DATA_RANGE] rd_from_decoder,
    input  wire [`DATA_RANGE] rs1_from_decoder,
    input  wire [`DATA_RANGE] rs2_from_decoder,
    input  wire [`DATA_RANGE] imm_from_decoder,
    input  wire is_load_store_from_decoder,
    input  wire is_btype_from_decoder,

    input  wire valid_from_ifetch,
    input  wire predicted_jump_from_ifetch,
    input  wire [`DATA_RANGE] predicted_pc_from_ifetch,
    input  wire [`DATA_RANGE] inst_from_ifetch,

    output reg  valid_to_rob,
    output reg  [`DATA_RANGE] pc_to_rob,
    output reg  [`REG_RANGE] rd_to_rob,
    output reg  is_btype_to_rob,
    output reg  is_load_store_to_rob,
    output reg  predicted_jump_to_rob,
    output reg  [`OPT_RANGE] inst_type_to_rob,
    output reg  [`ROB_RANGE] Qi_to_rob,
    output reg  [`ROB_RANGE] Qj_to_rob,
    input  wire Vi_valid_from_rob,
    input  wire [`DATA_RANGE] Vi_from_rob,
    input  wire Vj_valid_from_rob,
    input  wire [`DATA_RANGE] Vj_from_rob,
    input  wire [`ROB_RANGE] cur_alias_from_rob,

    output reg  renaming_valid_to_rf,
    output reg  [`REG_RANGE] renaming_reg_id_to_rf,
    output reg  [`ROB_RANGE] renaming_alias_to_rf,

    output reg  [`REG_RANGE] rs1_to_rf,
    output reg  [`REG_RANGE] rs2_to_rf,

    input  wire [`DATA_RANGE] Vi_from_rf,
    input  wire [`ROB_RANGE] Qi_from_rf,
    input  wire [`DATA_RANGE] Vj_from_rf,
    input  wire [`ROB_RANGE] Qj_from_rf,

    output reg  valid_to_res_stn,
    output reg  [`ROB_RANGE] alias_to_res_stn,
    output reg  [`OPT_RANGE] inst_type_to_res_stn,
    output reg  [`DATA_RANGE] Vi_to_res_stn,
    output reg  [`DATA_RANGE] Vj_to_res_stn,
    output reg  [`ROB_RANGE] Qi_to_res_stn,
    output reg  [`ROB_RANGE] Qj_to_res_stn,
    output reg  [`DATA_RANGE] imm_to_res_stn,
    output reg  [`DATA_RANGE] pc_to_res_stn,

    output reg  valid_to_lsb,
    output reg  [`ROB_RANGE] alias_to_lsb,
    output reg  [`OPT_RANGE] inst_type_to_lsb,
    output reg  [`DATA_RANGE] Vi_to_lsb,
    output reg  [`DATA_RANGE] Vj_to_lsb,
    output reg  [`ROB_RANGE] Qi_to_lsb,
    output reg  [`ROB_RANGE] Qj_to_lsb,
    output reg  [`DATA_RANGE] imm_to_lsb,
    output reg  [`DATA_RANGE] pc_to_lsb,

    input  wire valid_from_alu,
    input  wire [`ROB_RANGE] alias_from_alu,
    input  wire [`DATA_RANGE] result_from_alu,

    input  wire valid_from_lsb,
    input  wire [`ROB_RANGE] alias_from_lsb,
    input  wire [`DATA_RANGE] result_from_lsb
);
    wire [`ROB_RANGE] rob_Qi = Vi_valid_from_rob ? 0 : Qi_from_rf;
    wire [`DATA_RANGE] rob_Vi = Vi_valid_from_rob ? Vi_from_rob : Vi_from_rf;
    wire [`ROB_RANGE] Qi = (valid_from_alu && alias_from_alu == Qi_from_rf) ? 0 : (valid_from_lsb && alias_from_lsb == Qi_from_rf) ? 0 : rob_Qi;
    wire [`DATA_RANGE] Vi = (valid_from_alu && alias_from_alu == Qi_from_rf) ? result_from_alu : (valid_from_lsb && alias_from_lsb == Qi_from_rf) ? result_from_lsb : rob_Vi;

    wire [`ROB_RANGE] rob_Qj = Vj_valid_from_rob ? 0 : Qj_from_rf;
    wire [`DATA_RANGE] rob_Vj = Vj_valid_from_rob ? Vj_from_rob : Vj_from_rf;
    wire [`ROB_RANGE] Qj = (valid_from_alu && alias_from_alu == Qj_from_rf) ? 0 : (valid_from_lsb && alias_from_lsb == Qj_from_rf) ? 0 : rob_Qj;
    wire [`DATA_RANGE] Vj = (valid_from_alu && alias_from_alu == Qj_from_rf) ? result_from_alu : (valid_from_lsb && alias_from_lsb == Qj_from_rf) ? result_from_lsb : rob_Vj;

    assign data_to_decoder = inst_from_ifetch;
    
    always @(posedge clk) begin
        if (rst || rollback) begin
            // TODO
            valid_to_rob <= 1'b0;
            pc_to_rob <= 0;
            rd_to_rob <= 0;
            inst_type_to_rob <= 0;
            Qi_to_rob <= 0;
            Qj_to_rob <= 0;

            renaming_valid_to_rf <= 1'b0;
            renaming_reg_id_to_rf <= 0;
            renaming_alias_to_rf <= 0;

            rs1_to_rf <= 0;
            rs2_to_rf <= 0;

            valid_to_res_stn <= 1'b0;
            alias_to_res_stn <= 0;
            inst_type_to_res_stn <= 0;
            Vi_to_res_stn <= 0;
            Vj_to_res_stn <= 0;
            Qi_to_res_stn <= 0;
            Qj_to_res_stn <= 0;
            imm_to_res_stn <= 0;
            pc_to_res_stn <= 0;

            valid_to_lsb <= 1'b0;
            alias_to_lsb <= 0;
            inst_type_to_lsb <= 0;
            Vi_to_lsb <= 0;
            Vj_to_lsb <= 0;
            Qi_to_lsb <= 0;
            Qj_to_lsb <= 0;
            imm_to_lsb <= 0;
            pc_to_lsb <= 0;
        end
        else if (~rdy) begin end
        else begin
            // 功能：把指令分发到各个部件，以及给 register file 重命名信息！！！
            if (valid_from_ifetch && ~full) begin
                // Preparing to dispatch
                if (is_load_store_from_decoder) begin
                    valid_to_lsb <= 1'b1;
                    alias_to_lsb <= cur_alias_from_rob;
                    inst_type_to_lsb <= inst_type_from_decoder;
                    Vi_to_lsb <= Vi;
                    Vj_to_lsb <= Vj;
                    Qi_to_lsb <= Qi;
                    Qj_to_lsb <= Qj;
                    imm_to_lsb <= imm_from_decoder;
                    pc_to_lsb <= predicted_pc_from_ifetch;

                    valid_to_res_stn <= 1'b0;
                end
                else begin // TO Reservation station
                    valid_to_res_stn <= 1'b1;
                    alias_to_res_stn <= cur_alias_from_rob;
                    inst_type_to_res_stn <= inst_type_from_decoder;
                    Vi_to_res_stn <= Vi;
                    Vj_to_res_stn <= Vj;
                    Qi_to_res_stn <= Qi;
                    Qj_to_res_stn <= Qj;
                    imm_to_res_stn <= imm_from_decoder;
                    pc_to_res_stn <= predicted_pc_from_ifetch;

                    valid_to_lsb <= 1'b0;
                end

                // Renaming to reg file
                if (rd_from_decoder) begin
                    renaming_valid_to_rf <= 1'b1;
                    renaming_reg_id_to_rf <= rd_from_decoder;
                    renaming_alias_to_rf <= cur_alias_from_rob;
                end
                else begin
                    renaming_valid_to_rf <= 1'b0;
                end

                valid_to_rob <= 1'b1;
                pc_to_rob <= predicted_pc_from_ifetch;
                rd_to_rob <= rd_from_decoder;
                is_btype_to_rob <= is_btype_from_decoder;
                predicted_jump_to_rob <= predicted_jump_from_ifetch;
                inst_type_to_rob <= inst_type_from_decoder;
                is_load_store_to_rob <= is_load_store_from_decoder;
            end
            else begin
                valid_to_lsb <= 1'b0;
                valid_to_res_stn <= 1'b0;
                renaming_valid_to_rf <= 1'b0;
                valid_to_rob <= 1'b0;
            end
        end
    end

endmodule

// pc 与当前指令刚好错 1 位