`include "utils.v"

// 0 号位置不要存东西，不然怎么表示没有依赖！

module ROB(
    input  wire clk,
    input  wire rst,
    input  wire rdy,

    output wire rob_full,
    output reg  rollback,
    output reg  [`DATA_RANGE] rollback_pc,

    input  wire valid_from_lsb,
    input  wire [`ROB_RANGE] alias_from_lsb,
    input  wire [`DATA_RANGE] result_from_lsb,

    // 与 LSB 的交互：Load 指令读完 commit（commit 的过程定义为把读出来的值存进寄存器 / renamed 寄存器的过程）
    // Store 指令的 commit 是一个十分长的 store 过程，存完了才算 committed
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
    output reg  correctness_to_predictor,

    input  wire valid_from_disp,
    input  wire [`DATA_RANGE] pc_from_disp,
    input  wire [`REG_RANGE] rd_from_disp,
    input  wire is_btype_from_disp,
    input  wire predicted_jump_from_disp,
    input  wire [6:0] inst_type_from_disp,

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
    reg ready [`ROB_RANGE];
    reg [`DATA_RANGE] original_pc [`ROB_RANGE];
    reg [`DATA_RANGE] new_pc [`ROB_RANGE];
    reg is_btype [`ROB_RANGE];
    reg predicted_jump [`ROB_RANGE];
    reg really_jump [`ROB_RANGE];
    reg [6:0] inst_type[`ROB_RANGE];
    reg [`DATA_RANGE] result[`ROB_RANGE];
    reg [`REG_RANGE] rd[`ROB_RANGE];
    reg [`ROB_RANGE] head, tail;
    wire [`ROB_RANGE] next_head = (head == `ROB_SIZE - 1) ? 1 : head + 1;
    wire [`ROB_RANGE] next_tail = (tail == `ROB_SIZE - 1) ? 1 : tail + 1;

    assign rob_full = (head == next_tail);
    wire is_empty = (head == tail);

    assign cur_rename_id_to_disp = tail;
    assign Vi_valid_to_disp = ready[Qi_from_disp];
    assign Vi_to_disp = result[Qi_from_disp];
    assign Vj_valid_to_disp = ready[Qj_from_disp];
    assign Vj_to_disp = result[Qj_from_disp];


    integer i;
    always @(posedge clk) begin
        if (rst || rollback) begin
            head <= 1;
            tail <= 1;
            rollback <= 1'b0;
            valid_to_predictor <= 1'b0;
            really_jump_to_predictor <= 1'b0;
            real_pc_to_predictor <= 0;

            commit_command_to_lsb <= 1'b0;

            valid_to_reg_file <= 1'b0;
            for (i = 0; i < `ROB_SIZE; i = i + 1) begin
                ready[i] <= 0;
                is_btype[i] <= 0;
                predicted_jump[i] <= 0;
                really_jump[i] <= 0;
                original_pc[i] <= 0;
                new_pc[i] <= 0;
                inst_type[i] <= 0;
                result[i] <= 0;
                rd[i] <= 0;
            end
        end
        else if (~rdy) begin end
        else begin
            if (valid_from_disp && !rob_full) begin
                tail <= next_tail;
                ready[tail] <= 1'b0;
                is_btype[next_head] <= is_btype_from_disp;
                predicted_jump[next_head] <= predicted_jump_from_disp;
                // really_jump[next_head] <= 0;
                original_pc[next_head] <= pc_from_disp;
                // new_pc[next_head] <= pc_from_disp;
                inst_type[next_head] <= inst_type_from_disp;
                result[next_head] <= 0;
                rd[next_head] <= rd_from_disp;
            end

            if (valid_from_alu) begin
                ready[alias_from_alu] <= 1'b1;
                result[alias_from_alu] <= result_from_alu;
                really_jump[alias_from_alu] <= really_jump_from_alu;
                new_pc[alias_from_alu] <= real_pc_from_alu;
            end
            if (valid_from_lsb) begin
                // load 吗？
                // both
                ready[alias_from_lsb] <= 1'b1;
                result[alias_from_lsb] <= result_from_lsb;
            end

            if (~is_empty && ready[head]) begin
                head <= next_head;
                ready[head] <= 1'b0;
                if (is_btype[head]) begin
                    // 甩给 predictor
                    valid_to_predictor <= 1'b1;
                    really_jump_to_predictor <= really_jump[head];
                    real_pc_to_predictor <= new_pc[head];
                    if (really_jump[head] != predicted_jump[head]) begin
                        // Rollback
                        correctness_to_predictor <= 1'b0;
                        rollback <= 1'b1;
                        rollback_pc <= really_jump[head] ? new_pc[head] : original_pc[head] + 4;
                    end
                    else begin
                        correctness_to_predictor <= 1'b1;
                    end
                end
                else begin
                    valid_to_predictor <= 1'b0;
                end

                if (rd[head] != 0) begin
                        // 去找 RF
                        valid_to_reg_file <= 1'b1;
                        reg_id_to_reg_file <= rd[head];
                        result_to_reg_file <= result[head];
                        alias_to_reg_file <= head;
                    end
                else begin
                    valid_to_reg_file <= 1'b0;
                end
            end
            else begin
                valid_to_predictor <= 1'b0;
                valid_to_reg_file <= 1'b0;
            end
        end
    end

endmodule