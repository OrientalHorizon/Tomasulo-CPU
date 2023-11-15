`include "utils.v"

`define PREDICTOR_WIDTH 6
`define PREDICTOR_RANGE 7:2

module pc_register(
    input clk,
    input rst, // Reset
    output reg[5:0] pc,
    output reg ce
);
    always @(posedge clk) begin
        if (rst) begin
            pc <= 6'b0;
            ce <= 1'b0;
        end else begin
            pc <= pc + 4;
            ce <= 1'b1;
        end
    end

endmodule

module predictor(
    // General
    input wire clk,
    input wire rst,
    input wire rdy,

    // IF
    input wire [`DATA_RANGE] inst_id,
    input wire [`DATA_RANGE] cur_pc,
    output wire jump,

    // ROB commit 之后要更新状态
    input wire commit_pc_valid,
    input wire [`DATA_RANGE] commit_pc,
    input wire really_jump
);
    reg [1:0] prediction[`PREDICTOR_WIDTH-1:0];

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < `PREDICTOR_WIDTH; i = i + 1) begin
                prediction[i] <= 2'b0;
            end
        end

        else if (rdy == 1'b0) begin

        end
    end

    assign jump = prediction[cur_pc[`PREDICTOR_RANGE]][1];

    always @(posedge clk) begin
        if (rst && commit_pc_valid) begin
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