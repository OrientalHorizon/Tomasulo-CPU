`include "utils.v"

module register_file(
    input  wire clk,
    input  wire rst,
    input  wire rdy,

    input  wire rollback,

    input  wire [`REG_RANGE] rs1_from_disp,
    input  wire [`REG_RANGE] rs2_from_disp,

    output wire [`DATA_RANGE] Vi_to_disp,
    output wire [`ROB_RANGE] Qi_to_disp,
    output wire [`DATA_RANGE] Vj_to_disp,
    output wire [`ROB_RANGE] Qj_to_disp,
    
    input  wire renaming_valid,
    input  wire [`REG_RANGE] renaming_reg_id,
    input  wire [`ROB_RANGE] renaming_alias,

    input  wire result_valid_from_rob,
    input  wire [`REG_RANGE] reg_id_from_rob,
    input  wire [`ROB_RANGE] alias_from_rob,
    input  wire [`DATA_RANGE] result_from_rob
);
    reg [`DATA_RANGE] registers[31:0];
    reg [`ROB_RANGE] alias[31:0];

    // 如果 ROB 的最新 commit 涉及 rs1, rs2，那么它当然就没有依赖了，否则另说
    // 王世坚：就是这么简单.gif
    wire [`ROB_RANGE] rs1_alias = alias[rs1_from_disp];
    wire [`ROB_RANGE] rs2_alias = alias[rs2_from_disp];

    wire commit_rs1 = result_valid_from_rob && reg_id_from_rob == rs1_from_disp && alias_from_rob == rs1_alias;
    wire commit_rs2 = result_valid_from_rob && reg_id_from_rob == rs2_from_disp && alias_from_rob == rs2_alias;
    
    assign Qi_to_disp = commit_rs1 ? 0 : rs1_alias;
    assign Qj_to_disp = commit_rs2 ? 0 : rs2_alias;

    assign Vi_to_disp = commit_rs1 ? result_from_rob : registers[rs1_from_disp];
    assign Vj_to_disp = commit_rs2 ? result_from_rob : registers[rs2_from_disp];

    wire committing = (alias_from_rob == alias[reg_id_from_rob]);

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < `REGISTER_NUM; i = i + 1) begin
                registers[i] <= 0;
                alias[i] <= 0;
            end
        end
        else if (~rdy) begin end
        else begin
            if (rollback) begin
                for (i = 0; i < `REGISTER_NUM; i = i + 1) begin
                    alias[i] <= 0;
                end
            end
            else begin
                if (renaming_valid) begin
                    alias[renaming_reg_id] <= renaming_alias;
                end

                if (result_valid_from_rob && reg_id_from_rob != 5'b0) begin
                    if (committing) begin
                        alias[reg_id_from_rob] <= 5'b0;
                    end
                    registers[reg_id_from_rob] <= result_from_rob;
                end
            end
        end
    end

endmodule