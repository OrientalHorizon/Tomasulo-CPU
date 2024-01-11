`include "utils.v"

`define IDLE 3'b000
`define LOAD 3'b001
`define STORE 3'b010
`define ROLLBACK 3'b011

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
    input  wire [`OPT_RANGE] inst_type_from_disp,
    input  wire [`ROB_RANGE] rd_from_disp,
    input  wire [`ROB_RANGE] Qi_from_disp,
    input  wire [`ROB_RANGE] Qj_from_disp,
    input  wire [`DATA_RANGE] Vi_from_disp,
    input  wire [`DATA_RANGE] Vj_from_disp,
    input  wire [`DATA_RANGE] imm_from_disp,

    input  wire valid_from_memctrl,
    input  wire [`DATA_RANGE] data_from_memctrl,
    output reg  valid_to_memctrl,
    output reg  [`OPT_RANGE] inst_type_to_memctrl,
    output reg  [`ADDR_RANGE] addr_to_memctrl,
    output reg  [`DATA_RANGE] data_to_memctrl,

    input  wire valid_from_alu,
    input  wire [`ROB_RANGE] alias_from_alu,
    input  wire [`DATA_RANGE] result_from_alu,

    // CDB!!!
    output reg  valid_to_rob,
    output reg [`ROB_RANGE] alias_to_rob,
    output reg [`DATA_RANGE] result_to_rob
);
    `ifdef DEBUG
    integer outfile;
    initial begin
        outfile = $fopen("lsb.out");
    end
    `endif
    // 要实现一个循环队列
    reg write_or_read; // write = 0, read = 1

    reg [2:0] state;

    reg [`ROB_RANGE] id [`LSB_SIZE - 1 : 0];
    reg [`ROB_RANGE] Qi [`LSB_SIZE - 1 : 0];
    reg [`ROB_RANGE] Qj [`LSB_SIZE - 1 : 0];
    reg [`DATA_RANGE] Vi [`LSB_SIZE - 1 : 0];
    reg [`DATA_RANGE] Vj [`LSB_SIZE - 1 : 0];
    reg [`DATA_RANGE] imm [`LSB_SIZE - 1 : 0];
    reg [`OPT_RANGE] inst_type [`LSB_SIZE - 1 : 0];

    reg [`LSB_RANGE] head, tail;
    wire [`LSB_RANGE] next_head = (head == `LSB_SIZE - 1) ? 0 : head + 1;
    wire [`LSB_RANGE] next_tail = (tail == `LSB_SIZE - 1) ? 0 : tail + 1;
    wire is_empty = (head == tail);
    assign lsb_full = (next_tail == head);
    // 硬接线即可

    // forwarding line，如果当前周期就有结果，可能可以直接解决依赖
    // 数据类型！！！！！！！！！！！！！！！！！11
    wire [`ROB_RANGE] new_Qi = (valid_to_rob && (alias_to_rob == Qi_from_disp)) ? 0 : 
    (valid_from_alu && (alias_from_alu == Qi_from_disp)) ? 0 : Qi_from_disp;

    wire [`ROB_RANGE] new_Qj = (valid_to_rob && (alias_to_rob == Qj_from_disp)) ? 0 :
    (valid_from_alu && (alias_from_alu == Qj_from_disp)) ? 0 : Qj_from_disp;

    wire [`DATA_RANGE] new_Vi = (valid_to_rob && (alias_to_rob == Qi_from_disp)) ? result_to_rob :
    (valid_from_alu && (alias_from_alu == Qi_from_disp)) ? result_from_alu : Vi_from_disp;

    wire [`DATA_RANGE] new_Vj = (valid_to_rob && (alias_to_rob == Qj_from_disp)) ? result_to_rob :
    (valid_from_alu && (alias_from_alu == Qj_from_disp)) ? result_from_alu : Vj_from_disp;

    wire commit = commit_command_from_rob && (alias_to_store == id[head]);
    
    integer i;
    reg [31:0] clk_cnt = 0;
    always @(posedge clk) begin
        clk_cnt = clk_cnt + 1;
        if (rst || rollback_from_rob) begin
            state <= `IDLE;
            valid_to_memctrl <= 1'b0;
            valid_to_rob <= 1'b0;
            head <= 0; tail <= 0;
            data_to_memctrl <= 0;
            write_or_read <= `READ;
            alias_to_rob <= 0;
            result_to_rob <= 0;

            for (i = 0; i < `LSB_SIZE; i = i + 1) begin
                Vi[i] <= 0;
                Vj[i] <= 0;
                imm[i] <= 0;
                Qi[i] <= 0;
                Qj[i] <= 0;
                id[i] <= 0;
            end
        end
        else if (~rdy) begin end
        else begin
            if (valid_from_disp) begin
                tail <= next_tail;
                id[tail] <= rd_from_disp;
                inst_type[tail] <= inst_type_from_disp;
                Qi[tail] <= new_Qi;
                Qj[tail] <= new_Qj;
                Vi[tail] <= new_Vi;
                Vj[tail] <= new_Vj;
                imm[tail] <= imm_from_disp;
            end
            if (valid_from_alu) begin
                // 挨个扫 buffer 里面的东西，看看能不能消依赖
                for (i = 0; i < `LSB_SIZE; i = i + 1) begin
                    if (Qi[i] == alias_from_alu) begin
                        Qi[i] <= 0;
                        Vi[i] <= result_from_alu;
                    end
                    if (Qj[i] == alias_from_alu) begin
                        Qj[i] <= 0;
                        Vj[i] <= result_from_alu;
                    end
                end
            end
            if (valid_to_rob) begin
                for (i = 0; i < `LSB_SIZE; i = i + 1) begin
                    if (Qi[i] == alias_to_rob) begin
                        Qi[i] <= 0;
                        Vi[i] <= result_to_rob;
                    end
                    if (Qj[i] == alias_to_rob) begin
                        Qj[i] <= 0;
                        Vj[i] <= result_to_rob;
                    end
                end
            end

            case (state)
                `IDLE: begin
                    // 一次提交 valid_from_lsb 只能有一个周期为真，必须把 valid_from_lsb 设为 0
                    // 如果队列非空且可以提交，往 Memory controller 里面上东西
                    valid_to_rob <= 1'b0;
                    alias_to_rob <= 0;
                    if (head != tail && commit && !Qi[head] && !Qj[head]) begin
                        // 可以 commit
                        alias_to_rob <= id[head];
                        inst_type_to_memctrl <= inst_type[head];
                        addr_to_memctrl <= Vi[head] + imm[head];

                        case (inst_type[head])
                        // 确定状态机：什么时候开始读，什么时候开始写（这个周期还是下个周期）
                            `LB, `LBU, `LH, `LHU, `LW: begin
                                state <= `LOAD;
                                write_or_read <= `READ;
                                `ifdef DEBUG
                                $fdisplay(outfile, "load: addr = %h", Vi[head] + imm[head]);
                                `endif
                            end
                            `SB, `SH, `SW: begin
                                state <= `STORE;
                                write_or_read <= `WRITE;
                                data_to_memctrl <= Vj[head];
                                `ifdef DEBUG
                                $fdisplay(outfile, "store: addr = %h, value = %h", Vi[head] + imm[head], Vj[head]);
                                `endif
                            end
                        endcase

                        valid_to_memctrl <= 1'b1;
                        head <= next_head;
                    end
                    else begin
                        valid_to_memctrl <= 1'b0;
                    end
                end
                `LOAD: begin
                    if (valid_from_memctrl) begin
                        valid_to_rob <= 1'b1;
                        result_to_rob <= data_from_memctrl;
                        valid_to_memctrl <= 1'b0;

                        state <= `IDLE;
                    end
                    else begin
                        valid_to_rob <= 1'b0;
                    end
                end
                `STORE: begin
                    if (valid_from_memctrl) begin
                        valid_to_rob <= 1'b1;
                        result_to_rob <= 0;
                        valid_to_memctrl <= 1'b0;
                        write_or_read <= `READ;
                        
                        state <= `IDLE;
                    end
                    else begin
                        valid_to_rob <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule