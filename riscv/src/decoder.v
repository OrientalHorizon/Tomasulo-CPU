`include "utils.v"

module decoder(
    input  wire [`DATA_RANGE] inst_id,

    output reg  [`OPT_RANGE] opt,
    output reg  [4:0] rd,
    output reg  [4:0] rs1,
    output reg  [4:0] rs2,
    output reg  [`DATA_RANGE] imm,
    output reg  is_load_store,
    output reg  is_btype
);
    always @(*) begin
        case (inst_id[`OPT_RANGE])
            7'b0110111: begin // Only LUI
                is_load_store = 1'b0;
                is_btype = 1'b0;
                opt = `LUI;
                rd = inst_id[11:7];
                rs1 = 0;
                rs2 = 0;
                imm[31:12] = inst_id[31:12];
                imm[11:0] = 0;
            end

            7'b0010111: begin // Only AUIPC
                is_load_store = 1'b0;
                is_btype = 1'b0;
                opt = `AUIPC;
                rd = inst_id[11:7];
                rs1 = 0;
                rs2 = 0;
                imm[31:12] = inst_id[31:12];
                imm[11:0] = 0;
            end

            7'b1101111: begin // Only JAL
                is_load_store = 1'b0;
                is_btype = 1'b0;
                opt = `JAL;
                rd = inst_id[11:7];
                rs1 = 0;
                rs2 = 0;
                imm[20] = inst_id[31];
                imm[19:12] = inst_id[19:12];
                imm[11] = inst_id[20];
                imm[10:1] = inst_id[30:21];
                imm[0] = 0;
                // sign extend
                imm[31:21] = {11{imm[20]}};
            end

            7'b1100111: begin // Only JALR
                is_load_store = 1'b0;
                is_btype = 1'b0;
                opt = `JALR;
                rd = inst_id[11:7];
                rs1 = inst_id[19:15];
                rs2 = 0;
                imm[11:0] = inst_id[31:20];
                // sign extend
                imm[31:12] = {20{imm[11]}};
            end

            7'b1100011: begin // BEQ, BNE, BLT, BGE, BLTU, BGEU
                is_btype = 1'b1;
                is_load_store = 1'b0;
                case (inst_id[14:12])
                    3'b000: opt = `BEQ;
                    3'b001: opt = `BNE;
                    3'b100: opt = `BLT;
                    3'b101: opt = `BGE;
                    3'b110: opt = `BLTU;
                    3'b111: opt = `BGEU;
                endcase
                rd = 0;
                rs1 = inst_id[19:15];
                rs2 = inst_id[24:20];
                imm[12] = inst_id[31];
                imm[11] = inst_id[7];
                imm[10:5] = inst_id[30:25];
                imm[4:1] = inst_id[11:8];
                imm[0] = 0;
                // sign extend
                imm[31:12] = {20{imm[12]}};
            end

            7'b0000011: begin // LB, LH, LW, LBU, LHU
                is_load_store = 1'b1;
                is_btype = 1'b0;
                case (inst_id[14:12])
                    3'b000: opt = `LB;
                    3'b001: opt = `LH;
                    3'b010: opt = `LW;
                    3'b100: opt = `LBU;
                    3'b101: opt = `LHU;
                endcase
                rd = inst_id[11:7];
                rs1 = inst_id[19:15];
                rs2 = 0;
                imm[11:0] = inst_id[31:20];
                // sign extend
                imm[31:12] = {20{imm[11]}};
            end

            7'b0100011: begin// SB, SH, SW
                is_load_store = 1'b1;
                is_btype = 1'b0;
                case (inst_id[14:12])
                    3'b000: opt = `SB;
                    3'b001: opt = `SH;
                    3'b010: opt = `SW;
                endcase
                rd = 0;
                rs1 = inst_id[19:15];
                rs2 = inst_id[24:20];
                imm[11:5] = inst_id[31:25];
                imm[4:0] = inst_id[11:7];
                // sign extend
                imm[31:12] = {20{imm[11]}};
            end

            7'b0010011: begin // ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
                // Decoder 还能写错？？？？？？？？？？？！！！！
                // shabi Copilot
                is_load_store = 1'b0;
                is_btype = 1'b0;
                case (inst_id[14:12])
                    3'b000: opt = `ADDI;
                    3'b010: opt = `SLTI;
                    3'b011: opt = `SLTIU;
                    3'b100: opt = `XORI;
                    3'b110: opt = `ORI;
                    3'b111: opt = `ANDI;
                    3'b001: opt = `SLLI;
                    3'b101: begin
                        if (inst_id[31:26] == 6'b000000) begin
                            opt = `SRLI;
                        end
                        else begin
                            opt = `SRAI;
                        end
                    end
                endcase
                rd = inst_id[11:7];
                rs1 = inst_id[19:15];
                rs2 = 0;
                if (opt == `SLLI || opt == `SRLI || opt == `SRAI) begin
                    imm[31:5] = 0;
                    imm[5:0] = inst_id[25:20];
                end
                else begin
                    imm[11:0] = inst_id[31:20];
                    // sign extend
                    imm[31:12] = {20{imm[11]}};
                end
            end

            7'b0110011: begin
                is_load_store = 1'b0;
                is_btype = 1'b0;
                case (inst_id[14:12])
                    3'b000: begin
                        if (inst_id[31:25] == 7'b0000000) begin
                            opt = `ADD;
                        end else begin
                            opt = `SUB;
                        end
                    end
                    3'b001: opt = `SLL;
                    3'b010: opt = `SLT;
                    3'b011: opt = `SLTU;
                    3'b100: opt = `XOR;
                    3'b101: begin
                        if (inst_id[31:25] == 7'b0000000) begin
                            opt = `SRL;
                        end else begin
                            opt = `SRA;
                        end
                    end
                    3'b110: opt = `OR;
                    3'b111: opt = `AND;
                endcase
                rd = inst_id[11:7];
                rs1 = inst_id[19:15];
                rs2 = inst_id[24:20];
                imm[31:0] = 0;
            end
        endcase
    end

endmodule