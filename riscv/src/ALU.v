`include "utils.v"

module ALU(
    input  wire [`OPT_RANGE] opt,
    input  wire [`DATA_RANGE] rs1,
    input  wire [`DATA_RANGE] rs2,
    input  wire [`DATA_RANGE] imm,
    input  wire [`DATA_RANGE] pc,
    input  wire [`ROB_RANGE] target_rob_index,

    output reg  result_valid,
    output reg  [`DATA_RANGE] res,
    output reg  [`ROB_RANGE] target_rob_index_output,
    output reg  [`DATA_RANGE] pc_output,
    output reg  really_jump
);

    always @(*) begin
        target_rob_index_output = target_rob_index;
        really_jump = 1'b0;
        pc_output = 1'b0;
        result_valid = (opt != 0) ? 1'b1 : 1'b0; // 绷，一直 not valid 是吧
    
        case (opt)
            `LUI: begin // LUI
                res = imm;
            end

            `AUIPC: begin
                res = pc + imm;
            end

            `JAL: begin
                res = pc + 4;
                pc_output = pc + imm;
                really_jump = 1'b1; // ?
            end

            `JALR: begin
                res = pc + 4;
                pc_output = (rs1 + imm) & (~1);
                really_jump = 1'b1; // ?
            end

            `BEQ: begin
                // res = pc + 4;
                if (rs1 == rs2) begin
                    pc_output = pc + imm;
                    really_jump = 1'b1;
                end
            end

            `BNE: begin
                // res = pc + 4;
                if (rs1 != rs2) begin
                    pc_output = pc + imm;
                    really_jump = 1'b1;
                end
            end

            `BLT: begin
                // res = pc + 4;
                if ($signed(rs1) < $signed(rs2)) begin
                    pc_output = pc + imm;
                    really_jump = 1'b1;
                end
            end

            `BGE: begin
                // res = pc + 4;
                if ($signed(rs1) >= $signed(rs2)) begin
                    pc_output = pc + imm;
                    really_jump = 1'b1;
                end
            end

            `BLTU: begin
                // res = pc + 4;
                if (rs1 < rs2) begin
                    pc_output = pc + imm;
                    really_jump = 1'b1;
                end
            end

            `BGEU: begin
                // res = pc + 4;
                if (rs1 >= rs2) begin
                    pc_output = pc + imm;
                    really_jump = 1'b1;
                end
            end

            `ADDI: begin
                res = rs1 + imm;
            end

            `SLTI: begin
                res = ($signed(rs1) < $signed(imm)) ? 1'b1 : 1'b0;
            end

            `SLTIU: begin
                res = (rs1 < imm) ? 1'b1 : 1'b0;
            end

            `XORI: begin
                res = rs1 ^ imm;
            end

            `ORI: begin
                res = rs1 | imm;
            end

            `ANDI: begin
                res = rs1 & imm;
            end

            `SLLI: begin
                res = rs1 << imm;
            end

            `SRLI: begin
                res = rs1 >> imm;
            end

            `SRAI: begin
                res = rs1 >>> imm;
            end

            `ADD: begin
                res = rs1 + rs2;
            end

            `SUB: begin
                res = rs1 - rs2;
            end

            `SLL: begin
                res = rs1 << rs2;
            end

            `SLT: begin
                res = ($signed(rs1) < $signed(rs2)) ? 1'b1 : 1'b0;
            end

            `SLTU: begin
                res = (rs1 < rs2) ? 1'b1 : 1'b0;
            end

            `XOR: begin
                res = rs1 ^ rs2;
            end

            `SRL: begin
                res = rs1 >> rs2;
            end

            `SRA: begin
                res = rs1 >>> rs2;
            end

            `OR: begin
                res = rs1 | rs2;
            end

            `AND: begin
                res = rs1 & rs2;
            end

            default: begin
                res = 1'b0;
            end
        endcase
    end
endmodule