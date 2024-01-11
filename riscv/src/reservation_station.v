`include "utils.v"

module reservation_station(
    input  wire clk,
    input  wire rst,
    input  wire rdy,

    output wire rs_full,

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

    // CDB
    input  wire valid_from_alu,
    input  wire [`ROB_RANGE] alias_from_alu,
    input  wire [`DATA_RANGE] result_from_alu,

    output reg  valid_to_alu,
    output reg  [`OPT_RANGE] inst_type_to_alu,
    output reg  [`ROB_RANGE] alias_to_alu,
    output reg  [`DATA_RANGE] Vi_to_alu,
    output reg  [`DATA_RANGE] Vj_to_alu,
    output reg  [`DATA_RANGE] imm_to_alu,
    output reg  [`DATA_RANGE] pc_to_alu,

    // LSB 通过总线给 RS 信息消依赖 CDB
    input  wire valid_from_lsb,
    input  wire [`ROB_RANGE] alias_from_lsb,
    input  wire [`DATA_RANGE] result_from_lsb
);

    reg occupied [`RS_SIZE - 1 : 0];
    reg [`ROB_RANGE] id [`RS_SIZE - 1 : 0];
    reg [`ROB_RANGE] Qi [`RS_SIZE - 1 : 0];
    reg [`ROB_RANGE] Qj [`RS_SIZE - 1 : 0];
    reg [`DATA_RANGE] Vi [`RS_SIZE - 1 : 0];
    reg [`DATA_RANGE] Vj [`RS_SIZE - 1 : 0];
    reg [`DATA_RANGE] imm [`RS_SIZE - 1 : 0];
    reg [`DATA_RANGE] pc [`RS_SIZE - 1 : 0];
    reg [`OPT_RANGE] inst_type [`RS_SIZE - 1 : 0];

    assign rs_full = occupied[0] && occupied[1] && occupied[2] && occupied[3] && occupied[4] && occupied[5] && occupied[6] && occupied[7]
    && occupied[8] && occupied[9] && occupied[10] && occupied[11] && occupied[12] && occupied[13] && occupied[14] && occupied[15];

    wire [`RS_RANGE] first_available = !occupied[0] ? 0 : !occupied[1] ? 1 : !occupied[2] ? 2 : !occupied[3] ? 3 : !occupied[4] ? 4 : !occupied[5] ? 5 : !occupied[6] ? 6 : !occupied[7] ? 7
    : !occupied[8] ? 8 : !occupied[9] ? 9 : !occupied[10] ? 10 : !occupied[11] ? 11 : !occupied[12] ? 12 : !occupied[13] ? 13 : !occupied[14] ? 14 : !occupied[15] ? 15 : 16;
    wire [`RS_RANGE] slot_ready_for_alu = (occupied[0] && !Qi[0] && !Qj[0]) ? 0 : (occupied[1] && !Qi[1] && !Qj[1]) ? 1 : (occupied[2] && !Qi[2] && !Qj[2]) ? 2 : (occupied[3] && !Qi[3] && !Qj[3]) ? 3
    : (occupied[4] && !Qi[4] && !Qj[4]) ? 4 : (occupied[5] && !Qi[5] && !Qj[5]) ? 5 : (occupied[6] && !Qi[6] && !Qj[6]) ? 6 : (occupied[7] && !Qi[7] && !Qj[7]) ? 7
    : (occupied[8] && !Qi[8] && !Qj[8]) ? 8 : (occupied[9] && !Qi[9] && !Qj[9]) ? 9 : (occupied[10] && !Qi[10] && !Qj[10]) ? 10 : (occupied[11] && !Qi[11] && !Qj[11]) ? 11
    : (occupied[12] && !Qi[12] && !Qj[12]) ? 12 : (occupied[13] && !Qi[13] && !Qj[13]) ? 13 : (occupied[14] && !Qi[14] && !Qj[14]) ? 14 : (occupied[15] && !Qi[15] && !Qj[15]) ? 15 : 16;

    // forwarding line，类似 LSB
    wire [`ROB_RANGE] new_Qi = (valid_from_lsb && (alias_from_lsb == Qi_from_disp)) ? 0 : 
    (valid_from_alu && (alias_from_alu == Qi_from_disp)) ? 0 : Qi_from_disp;

    wire [`ROB_RANGE] new_Qj = (valid_from_lsb && (alias_from_lsb == Qj_from_disp)) ? 0 :
    (valid_from_alu && (alias_from_alu == Qj_from_disp)) ? 0 : Qj_from_disp;

    wire [`DATA_RANGE] new_Vi = (valid_from_lsb && (alias_from_lsb == Qi_from_disp)) ? result_from_lsb :
    (valid_from_alu && (alias_from_alu == Qi_from_disp)) ? result_from_alu : Vi_from_disp;

    wire [`DATA_RANGE] new_Vj = (valid_from_lsb && (alias_from_lsb == Qj_from_disp)) ? result_from_lsb :
    (valid_from_alu && (alias_from_alu == Qj_from_disp)) ? result_from_alu : Vj_from_disp;
    
    integer i;
    always @(posedge clk) begin
        if (rst || rollback_from_rob) begin
            valid_to_alu <= 1'b0;
            inst_type_to_alu <= 0;
            alias_to_alu <= 0;
            Vi_to_alu <= 0;
            Vj_to_alu <= 0;
            imm_to_alu <= 0;
            pc_to_alu <= 0;

            for (i = 0; i < `RS_SIZE; i = i + 1) begin
                occupied[i] <= 0;
                id[i] <= 0;
                Qi[i] <= 0; Qj[i] <= 0;
                Vi[i] <= 0; Vj[i] <= 0;
                imm[i] <= 0; pc[i] <= 0;
                inst_type[i] <= 0;
            end
        end
        else if (~rdy) begin end
        else begin
            if (valid_from_disp && !rs_full) begin
                occupied[first_available] <= 1'b1;
                id[first_available] <= rd_from_disp;
                Qi[first_available] <= new_Qi;
                Qj[first_available] <= new_Qj;
                Vi[first_available] <= new_Vi;
                Vj[first_available] <= new_Vj;
                imm[first_available] <= imm_from_disp;
                pc[first_available] <= pc_from_disp;
                inst_type[first_available] <= inst_type_from_disp;
            end

            if (slot_ready_for_alu != `RS_SIZE) begin
                valid_to_alu <= 1'b1;
                inst_type_to_alu <= inst_type[slot_ready_for_alu];
                alias_to_alu <= id[slot_ready_for_alu];
                Vi_to_alu <= Vi[slot_ready_for_alu];
                Vj_to_alu <= Vj[slot_ready_for_alu];
                imm_to_alu <= imm[slot_ready_for_alu];
                pc_to_alu <= pc[slot_ready_for_alu];

                occupied[slot_ready_for_alu] <= 1'b0;
            end
            else begin
                valid_to_alu <= 1'b0;
                inst_type_to_alu <= 0;
                alias_to_alu <= 0;
            end

            // 撤依赖
            if (valid_from_alu) begin
                // 挨个扫 buffer 里面的东西，看看能不能消依赖
                for (i = 0; i < `RS_SIZE; i = i + 1) begin
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

            if (valid_from_lsb) begin
                for (i = 0; i < `RS_SIZE; i = i + 1) begin
                    if (Qi[i] == alias_from_lsb) begin
                        Qi[i] <= 0;
                        Vi[i] <= result_from_lsb;
                    end
                    if (Qj[i] == alias_from_lsb) begin
                        Qj[i] <= 0;
                        Vj[i] <= result_from_lsb;
                    end
                end
            end
        end
    end
    
endmodule