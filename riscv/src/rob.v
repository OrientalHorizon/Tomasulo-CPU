`include "utils.v"

// 0 号位置不要存东西，不然怎么表示没有依赖！

module ROB(
    input  wire clk,
    input  wire rst,
    input  wire rdy,

    output wire rob_full,
    output reg  rollback,
    output reg  [`DATA_RANGE] rollback_pc,

    // CDB
    input  wire valid_from_lsb,
    input  wire [`ROB_RANGE] alias_from_lsb,
    input  wire [`DATA_RANGE] result_from_lsb,

    // 与 LSB 的交互：Load 指令读完 commit（commit 的过程定义为把读出来的值存进寄存器 / renamed 寄存器的过程）
    // Store 指令的 commit 是一个十分长的 store 过程，存完了才算 committed
    output wire commit_command_to_lsb,
    output wire [`ROB_RANGE] alias_to_store,

    // CDB
    input  wire valid_from_alu,
    input  wire [`ROB_RANGE] alias_from_alu,
    input  wire [`DATA_RANGE] result_from_alu,

    input  wire really_jump_from_alu,
    input  wire [`DATA_RANGE] real_pc_from_alu,

    output reg  valid_to_predictor,
    output reg  really_jump_to_predictor,
    output reg  [`DATA_RANGE] branch_pc_to_predictor,
    // output reg  correctness_to_predictor,

    input  wire valid_from_disp,
    input  wire [`DATA_RANGE] pc_from_disp,
    input  wire [`REG_RANGE] rd_from_disp,
    input  wire is_btype_from_disp,
    input  wire is_load_store_from_disp,
    input  wire predicted_jump_from_disp,
    input  wire [`OPT_RANGE] inst_type_from_disp,

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
    // fuck！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！所有的数组检查一遍，下标范围不要再出问题了！！！！！1
    `ifdef DEBUG
    integer outfile;
    initial begin
        outfile = $fopen("test1.out");
    end
    `endif
    reg ready [`ROB_SIZE - 1 : 0];
    reg [`DATA_RANGE] original_pc [`ROB_SIZE - 1 : 0];
    reg [`DATA_RANGE] new_pc [`ROB_SIZE - 1 : 0];
    reg is_btype [`ROB_SIZE - 1 : 0];
    reg is_load_store [`ROB_SIZE - 1 : 0];
    reg predicted_jump [`ROB_SIZE - 1 : 0];
    reg really_jump [`ROB_SIZE - 1 : 0];
    reg [6:0] inst_type [`ROB_SIZE - 1 : 0];
    reg [`DATA_RANGE] result [`ROB_SIZE - 1 : 0];
    reg [`REG_RANGE] rd [`ROB_SIZE - 1 : 0];
    reg [`ROB_RANGE] head, tail;
    wire [`ROB_RANGE] next_head = (head == `ROB_SIZE - 1) ? 1 : head + 1;
    wire [`ROB_RANGE] next_tail = (tail == `ROB_SIZE - 1) ? 1 : tail + 1;

    // 一样的，tail 是假的，指向队尾的后一位，head 是真的

    assign rob_full = (head == next_tail);
    wire is_empty = (head == tail);

    assign cur_rename_id_to_disp = tail;
    assign Vi_valid_to_disp = ready[Qi_from_disp];
    assign Vi_to_disp = result[Qi_from_disp];
    assign Vj_valid_to_disp = ready[Qj_from_disp];
    assign Vj_to_disp = result[Qj_from_disp];

    wire debug_is_ls = is_load_store[head]; // 所以为什么 >= <= 号会出问题？？？？A: 不是这个的问题
    assign commit_command_to_lsb = ((~is_empty) && debug_is_ls);
    assign alias_to_store = head;

    integer i;
    reg [31:0] clk_cnt = 0;
    always @(posedge clk) begin
        clk_cnt = clk_cnt + 1;
        if (rst || rollback) begin
            head <= 1;
            tail <= 1;
            rollback <= 1'b0;
            valid_to_predictor <= 1'b0;
            really_jump_to_predictor <= 1'b0;
            branch_pc_to_predictor <= 0;

            valid_to_reg_file <= 1'b0;
            for (i = 0; i < `ROB_SIZE; i = i + 1) begin
                is_load_store[i] <= 0;
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
                // $fdisplay(outfile, "tail = %h, tmp_pc = %h", tail, pc_from_disp);
                // $fdisplay(outfile, "inst_type = %d", inst_type_from_disp);
                // $fdisplay(outfile, "is_load_store = %d", is_load_store_from_disp);
                tail <= next_tail;
                ready[tail] <= 1'b0;
                is_btype[tail] <= is_btype_from_disp;
                predicted_jump[tail] <= predicted_jump_from_disp;
                original_pc[tail] <= pc_from_disp;
                inst_type[tail] <= inst_type_from_disp;
                is_load_store[tail] <= is_load_store_from_disp;
                result[tail] <= 0;
                rd[tail] <= rd_from_disp; // 写成 next_head，怎么想的？
            end

            if (valid_from_alu) begin
                // $fdisplay(outfile, "CDB valid from alu: alias = %h", alias_from_alu);
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
                `ifdef DEBUG
                $fdisplay(outfile, "commit: pc = %h", original_pc[head]);
                `endif
                // if (original_pc[head] == 32'h0000114c) begin
                //     $fdisplay(outfile, "really_jump: %h", really_jump[head]);
                // end
                head <= next_head;
                ready[head] <= 1'b0;
                if (is_btype[head] || inst_type[head] == `JAL || inst_type[head] == `JALR) begin
                    // 甩给 predictor
                    // $fdisplay(outfile, "Jump processing: pc = %h, inst_type = %h", original_pc[head], inst_type[head]);
                    valid_to_predictor <= 1'b1;
                    really_jump_to_predictor <= really_jump[head];
                    branch_pc_to_predictor <= original_pc[head];
                    if (really_jump[head] != predicted_jump[head]) begin
                        // Rollback
                        // correctness_to_predictor <= 1'b0;
                        // 会考虑 JALR 的。
                        rollback <= 1'b1;
                        rollback_pc <= really_jump[head] ? new_pc[head] : original_pc[head] + 4;
                        // $display("really_jump[head], new_pc[head], original_pc[head]: %h, %h, %h", really_jump[head], new_pc[head], original_pc[head]);
                    end
                    else begin
                        // correctness_to_predictor <= 1'b1;
                        rollback <= 1'b0;
                    end
                end
                else begin
                    valid_to_predictor <= 1'b0;
                end

                if (rd[head] != 0) begin
                    // 去找 RF
                    `ifdef DEBUG
                    $fdisplay(outfile, "commit to rf: reg_id = %h, result = %h", rd[head], result[head]);
                    `endif
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