`include "utils.v"

`define PREDICTOR_WIDTH 6
`define PREDICTOR_RANGE 7:2

`define WORKING 2'b00
`define FETCHING 2'b01
`define ROLLBACK 2'b10

`define B_TYPE 7'b1100011
`define JAL 7'b1101111

// module pc_register(
//     input  wire clk,
//     input  wire rst, // Reset
//     output reg[5:0] pc,
//     output reg ce
// );
//     always @(posedge clk) begin
//         if (rst) begin
//             pc <= 6'b0;
//             ce <= 1'b0;
//         end else begin
//             pc <= pc + 4;
//             ce <= 1'b1;
//         end
//     end

// endmodule

module predictor(
    // General
    input  wire clk,
    input  wire rst,
    input  wire rdy,

    // IF
    input  wire [`DATA_RANGE] cur_pc,
    output wire jump,

    // ROB commit 之后要更新状态
    input  wire commit_pc_valid,
    input  wire [`DATA_RANGE] commit_pc,
    input  wire really_jump
);
    reg [1:0] prediction[`PREDICTOR_WIDTH-1:0];

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < `PREDICTOR_WIDTH; i = i + 1) begin
                prediction[i] <= 2'b0;
            end
        end

        else if (~rdy) begin
            
        end
    end

    assign jump = prediction[cur_pc[`PREDICTOR_RANGE]][1];

    always @(posedge clk) begin
        if (commit_pc_valid) begin
            if (really_jump) begin
                if (prediction[commit_pc[`PREDICTOR_RANGE]] != 2'b11) begin
                    prediction[commit_pc[`PREDICTOR_RANGE]] <= prediction[commit_pc[`PREDICTOR_RANGE]] + 1;
                end
            end
            else begin
                if (prediction[commit_pc[`PREDICTOR_RANGE]] != 2'b00) begin
                    prediction[commit_pc[`PREDICTOR_RANGE]] <= prediction[commit_pc[`PREDICTOR_RANGE]] - 1;
                end
            end
        end
    end

endmodule

module IFetch(
    input  wire clk,
    input  wire rst,
    input  wire rdy,

    input  wire blocked, // 后面的一个结构满了，不要再读了

    input  wire valid_from_icache,
    input  wire [`DATA_RANGE] inst_from_icache,
    output reg  valid_to_icache,
    output reg  [`DATA_RANGE] pc_to_icache,

    input  wire is_jump_from_manager,
    input  wire [`DATA_RANGE] next_pc_from_manager,
    output wire [`DATA_RANGE] inst_to_manager,
    output wire [`DATA_RANGE] pc_to_manager,

    output reg valid_to_dispatcher,
    output reg [`DATA_RANGE] pc_to_dispatcher,
    output reg [`DATA_RANGE] inst_to_dispatcher,
    output reg is_jump_to_dispatcher,
    
    input  wire rollback_from_rob,
    input  wire [`DATA_RANGE] rollback_pc_from_rob
);
    reg [1:0] status;
    reg [`DATA_RANGE] local_pc;

    assign inst_to_manager = inst_from_icache;
    assign pc_to_manager = local_pc;

    always @(posedge clk) begin
        if (rst) begin
            local_pc <= 0;
            pc_to_dispatcher <= 0;
            pc_to_icache <= 0;
            valid_to_dispatcher <= 0;
            valid_to_icache <= 0;
            inst_to_dispatcher <= 0;
            status <= `FETCHING;
        end
        else if (~rdy) begin end
        else if (rollback_from_rob) begin
            status <= `ROLLBACK;
            valid_to_dispatcher <= 0;
        end
        else begin
            // 跑状态机
            if (status == `WORKING && ~blocked) begin
                if (valid_from_icache) begin
                    status <= `FETCHING;
                    local_pc <= next_pc_from_manager;
                    valid_to_dispatcher <= 1;
                    inst_to_dispatcher <= inst_from_icache;
                    pc_to_dispatcher <= next_pc_from_manager;
                    is_jump_to_dispatcher <= is_jump_from_manager;

                    valid_to_icache <= 0;
                end
            end

            if (status == `FETCHING) begin
                if (~blocked) begin
                    valid_to_dispatcher <= 0;

                    valid_to_icache <= 1;
                    pc_to_icache <= local_pc;
                    status <= `WORKING;
                end
                else begin
                    valid_to_icache <= 0;
                end
            end
        end
    end

endmodule

// predictor 的预测是硬接线，这个也要
module pc_manager(
    input  wire clk,
    input  wire rst,
    input  wire rdy,

    input  wire [`DATA_RANGE] inst_from_if,
    input  wire [`DATA_RANGE] pc_from_if,
    output wire is_jump_to_if,
    output wire [`DATA_RANGE] next_pc_to_if,

    input  wire is_jump_from_pred,
    output wire [`DATA_RANGE] pc_to_pred
);
    // 硬接线
    wire is_btype = inst_from_if[`OPT_RANGE] == `B_TYPE;
    wire is_jal = inst_from_if[`OPT_RANGE] == `JAL;
    wire need_manager = is_btype || is_jal;
    wire [`DATA_RANGE] imm_jal;
    wire [`DATA_RANGE] imm_branch;

    assign imm_jal = {{12{inst_from_if[31]}}, inst_from_if[19:12], inst_from_if[20], inst_from_if[30:21], 1'b0};
    assign imm_branch = {{20{inst_from_if[31]}}, inst_from_if[7], inst_from_if[30:25], inst_from_if[11:8], 1'b0};
    wire [`DATA_RANGE] pc_offset = is_btype ? imm_branch : imm_jal;

    assign pc_to_pred = is_btype ? pc_from_if : 0;
    assign is_jump_by_manager = is_btype ? is_jump_from_pred : 1'b1;
    assign is_jump_to_if = need_manager ? is_jump_by_manager : 1'b0;
    assign next_pc_to_if = is_jump_to_if ? pc_from_if + pc_offset : pc_from_if + 4;

    always @(posedge clk) begin
        if (rst) begin
        end
        else if (~rdy) begin end
    end

endmodule