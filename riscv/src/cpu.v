`include "utils.v"
// `include "decoder.v"
// `include "dispatcher.v"
// `include "ifetch.v"
// `include "load_store_buffer.v"
// `include "memctrl.v"
// `include "cache.v"
// `include "rob.v"
// `include "ALU.v"
// `include "reservation_station.v"
// `include "reg_file.v"
// RISCV32I CPU top module
// port modification allowed for debugging purposes

module cpu(
    input  wire                 clk_in,			// system clock signal
    input  wire                 rst_in,			// reset signal
    input  wire			        rdy_in,			// ready signal, pause cpu when low

    input  wire [ 7:0]          mem_din,		// data input bus, data_from_ram
    output wire [ 7:0]          mem_dout,		// data output bus, data_to_ram
    output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
    output wire                 mem_wr,			// write/read signal (1 for write)
	
	input  wire                 io_buffer_full, // 1 if uart buffer is full
	
	output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
);

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)

    wire rollback_signal_from_rob;
    wire [`DATA_RANGE] rollback_pc_from_rob;

    wire valid_icache_to_mem_ctrl;
    wire [`ADDR_RANGE] addr_icache_to_mem_ctrl;
    wire valid_mem_ctrl_to_icache;
    wire [`DATA_RANGE] data_mem_ctrl_to_icache;

    wire valid_lsb_to_mem_ctrl;
    wire [`ADDR_RANGE] addr_lsb_to_mem_ctrl;
    wire [`DATA_RANGE] data_lsb_to_mem_ctrl;
    wire [`OPT_RANGE] inst_type_lsb_to_mem_ctrl;
    wire valid_mem_ctrl_to_lsb;
    wire [`DATA_RANGE] data_mem_ctrl_to_lsb;

    // wire uart_full_mem_to_ctrl;
    // wire [7:0] data_mem_to_ctrl;
    // wire write_or_read_ctrl_to_mem;
    // wire [`ADDR_RANGE] addr_ctrl_to_mem;
    // wire [7:0] data_ctrl_to_mem;

    wire rob_is_full, rs_is_full, lsb_is_full;

    wire is_full = rob_is_full | rs_is_full | lsb_is_full;

    wire global_rollback;
    wire [`DATA_RANGE] global_rollback_pc;

    wire tmp_io_buffer_full = 0;
    
    // Mem ctrl
    mem_ctrl memory_controller(
        .clk(clk_in),
        .rst(rst_in),
        .rdy(rdy_in),

        .valid_from_icache(valid_icache_to_mem_ctrl),
        .addr_from_icache(addr_icache_to_mem_ctrl),
        .valid_to_icache(valid_mem_ctrl_to_icache),
        .data_to_icache(data_mem_ctrl_to_icache),

        .valid_from_lsb(valid_lsb_to_mem_ctrl),
        .addr_from_lsb(addr_lsb_to_mem_ctrl),
        .data_from_lsb(data_lsb_to_mem_ctrl),
        .inst_type_from_lsb(inst_type_lsb_to_mem_ctrl),
        .valid_to_lsb(valid_mem_ctrl_to_lsb),
        .data_to_lsb(data_mem_ctrl_to_lsb),

        .uart_full(tmp_io_buffer_full),
        .data_from_ram(mem_din),
        .write_or_read(mem_wr),
        .addr_to_ram(mem_a),
        .data_to_ram(mem_dout)
    );

    wire valid_ifetch_to_icache;
    wire [`DATA_RANGE] pc_ifetch_to_icache;
    wire valid_icache_to_ifetch;
    wire [`DATA_RANGE] data_icache_to_ifetch;

    // ICache
    ICache icache(
        .clk(clk_in),
        .rst(rst_in),
        .rdy(rdy_in),

        .valid_from_ifetch(valid_ifetch_to_icache),
        .pc_from_ifetch(pc_ifetch_to_icache),
        .valid_to_ifetch(valid_icache_to_ifetch),
        .data_to_ifetch(data_icache_to_ifetch),

        .valid_from_memctrl(valid_mem_ctrl_to_icache),
        .data_from_memctrl(data_mem_ctrl_to_icache),
        .valid_to_memctrl(valid_icache_to_mem_ctrl),
        .addr_to_memctrl(addr_icache_to_mem_ctrl)
    );

    wire is_jump_manager_to_ifetch;
    wire [`DATA_RANGE] next_pc_manager_to_ifetch;
    wire [`DATA_RANGE] inst_ifetch_to_manager;
    wire [`DATA_RANGE] pc_ifetch_to_manager;
    wire valid_ifetch_to_disp;
    wire [`DATA_RANGE] pc_ifetch_to_disp;
    wire [`DATA_RANGE] inst_ifetch_to_disp;
    wire is_jump_ifetch_to_disp;

    // IFetch
    IFetch ifetch(
        .clk(clk_in),
        .rst(rst_in),
        .rdy(rdy_in),

        .blocked(is_full),

        .valid_from_icache(valid_icache_to_ifetch),
        .inst_from_icache(data_icache_to_ifetch),
        .valid_to_icache(valid_ifetch_to_icache),
        .pc_to_icache(pc_ifetch_to_icache),

        .is_jump_from_manager(is_jump_manager_to_ifetch),
        .next_pc_from_manager(next_pc_manager_to_ifetch),
        .inst_to_manager(inst_ifetch_to_manager),
        .pc_to_manager(pc_ifetch_to_manager),

        .valid_to_dispatcher(valid_ifetch_to_disp),
        .pc_to_dispatcher(pc_ifetch_to_disp),
        .inst_to_dispatcher(inst_ifetch_to_disp),
        .is_jump_to_dispatcher(is_jump_ifetch_to_disp),

        .rollback_from_rob(global_rollback),
        .rollback_pc_from_rob(global_rollback_pc)
    );

    wire is_jump_pred_to_manager;
    wire [`DATA_RANGE] pc_manager_to_pred;

    // PC manager
    pc_manager pc_manager_(
        .clk(clk_in),
        .rst(rst_in),
        .rdy(rdy_in),

        .inst_from_if(inst_ifetch_to_manager),
        .pc_from_if(pc_ifetch_to_manager),
        .is_jump_to_if(is_jump_manager_to_ifetch),
        .next_pc_to_if(next_pc_manager_to_ifetch),

        .is_jump_from_pred(is_jump_pred_to_manager),
        .pc_to_pred(pc_manager_to_pred)
    );

    wire valid_rob_to_pred;
    wire [`DATA_RANGE] pc_rob_to_pred;
    wire really_jump_rob_to_pred;

    // predictor
    predictor pred(
        .clk(clk_in),
        .rst(rst_in),
        .rdy(rdy_in),

        .cur_pc(pc_manager_to_pred),
        .jump(is_jump_pred_to_manager),

        .commit_pc_valid(valid_rob_to_pred),
        .commit_pc(pc_rob_to_pred),
        .really_jump(really_jump_rob_to_pred)
    );

    wire [`DATA_RANGE] data_disp_to_decoder;
    wire [`OPT_RANGE] inst_type_decoder_to_disp;
    wire [4:0] rd_decoder_to_disp;
    wire [4:0] rs1_decoder_to_disp;
    wire [4:0] rs2_decoder_to_disp;
    wire [`DATA_RANGE] imm_decoder_to_disp;
    wire is_load_store_decoder_to_disp;
    wire is_btype_decoder_to_disp;

    wire valid_disp_to_rob;
    wire [`DATA_RANGE] pc_disp_to_rob;
    wire [`REG_RANGE] rd_disp_to_rob;
    wire is_btype_disp_to_rob;
    wire is_load_store_disp_to_rob;
    wire predicted_jump_disp_to_rob;
    wire [`OPT_RANGE] inst_type_disp_to_rob;
    wire [`ROB_RANGE] Qi_disp_to_rob;
    wire [`ROB_RANGE] Qj_disp_to_rob;
    wire Vi_valid_rob_to_disp;
    wire [`DATA_RANGE] Vi_rob_to_disp;
    wire Vj_valid_rob_to_disp;
    wire [`DATA_RANGE] Vj_rob_to_disp;
    wire [`ROB_RANGE] cur_alias_rob_to_disp;

    wire renaming_valid_disp_to_rf;
    wire [`REG_RANGE] renaming_reg_id_disp_to_rf;
    wire [`ROB_RANGE] renaming_alias_disp_to_rf;

    wire [`REG_RANGE] rs1_disp_to_rf;
    wire [`REG_RANGE] rs2_disp_to_rf;

    wire [`DATA_RANGE] Vi_rf_to_disp;
    wire [`ROB_RANGE] Qi_rf_to_disp;
    wire [`DATA_RANGE] Vj_rf_to_disp;
    wire [`ROB_RANGE] Qj_rf_to_disp;

    wire valid_disp_to_res_stn;
    wire [`ROB_RANGE] alias_disp_to_res_stn;
    wire [`OPT_RANGE] inst_type_disp_to_res_stn;
    wire [`DATA_RANGE] Vi_disp_to_res_stn;
    wire [`DATA_RANGE] Vj_disp_to_res_stn;
    wire [`ROB_RANGE] Qi_disp_to_res_stn;
    wire [`ROB_RANGE] Qj_disp_to_res_stn;
    wire [`DATA_RANGE] imm_disp_to_res_stn;
    wire [`DATA_RANGE] pc_disp_to_res_stn;

    wire valid_disp_to_lsb;
    wire [`ROB_RANGE] alias_disp_to_lsb;
    wire [`OPT_RANGE] inst_type_disp_to_lsb;
    wire [`DATA_RANGE] Vi_disp_to_lsb;
    wire [`DATA_RANGE] Vj_disp_to_lsb;
    wire [`ROB_RANGE] Qi_disp_to_lsb;
    wire [`ROB_RANGE] Qj_disp_to_lsb;
    wire [`DATA_RANGE] imm_disp_to_lsb;
    wire [`DATA_RANGE] pc_disp_to_lsb;

    // CDB!!!!!!!!!!!!!!!!!!!!!!!
    wire valid_alu_to_cdb;
    wire [`ROB_RANGE] alias_alu_to_cdb;
    wire [`DATA_RANGE] result_alu_to_cdb;

    wire valid_lsb_to_cdb;
    wire [`ROB_RANGE] alias_lsb_to_cdb;
    wire [`DATA_RANGE] result_lsb_to_cdb;

    // dispatcher
    dispatcher dispatch(
        .clk(clk_in),
        .rst(rst_in),
        .rdy(rdy_in),

        .full(is_full),
        .rollback(global_rollback),

        .data_to_decoder(data_disp_to_decoder),
        .inst_type_from_decoder(inst_type_decoder_to_disp),
        .rd_from_decoder(rd_decoder_to_disp),
        .rs1_from_decoder(rs1_decoder_to_disp),
        .rs2_from_decoder(rs2_decoder_to_disp),
        .imm_from_decoder(imm_decoder_to_disp),
        .is_load_store_from_decoder(is_load_store_decoder_to_disp),
        .is_btype_from_decoder(is_btype_decoder_to_disp),

        .valid_from_ifetch(valid_ifetch_to_disp),
        .predicted_jump_from_ifetch(is_jump_ifetch_to_disp),
        // predicted jump or not = 预测跳不跳转
        .predicted_pc_from_ifetch(pc_ifetch_to_disp),
        .inst_from_ifetch(inst_ifetch_to_disp),

        .valid_to_rob(valid_disp_to_rob),
        .pc_to_rob(pc_disp_to_rob),
        .rd_to_rob(rd_disp_to_rob),
        .is_btype_to_rob(is_btype_disp_to_rob),
        .is_load_store_to_rob(is_load_store_disp_to_rob),
        .predicted_jump_to_rob(predicted_jump_disp_to_rob),
        .inst_type_to_rob(inst_type_disp_to_rob),
        .Qi_to_rob(Qi_disp_to_rob),
        .Qj_to_rob(Qj_disp_to_rob),
        .Vi_valid_from_rob(Vi_valid_rob_to_disp),
        .Vi_from_rob(Vi_rob_to_disp),
        .Vj_valid_from_rob(Vj_valid_rob_to_disp),
        .Vj_from_rob(Vj_rob_to_disp),
        .cur_alias_from_rob(cur_alias_rob_to_disp),

        .renaming_valid_to_rf(renaming_valid_disp_to_rf),
        .renaming_reg_id_to_rf(renaming_reg_id_disp_to_rf),
        .renaming_alias_to_rf(renaming_alias_disp_to_rf),

        .rs1_to_rf(rs1_disp_to_rf),
        .rs2_to_rf(rs2_disp_to_rf),

        .Vi_from_rf(Vi_rf_to_disp),
        .Qi_from_rf(Qi_rf_to_disp),
        .Vj_from_rf(Vj_rf_to_disp),
        .Qj_from_rf(Qj_rf_to_disp),

        .valid_to_res_stn(valid_disp_to_res_stn),
        .alias_to_res_stn(alias_disp_to_res_stn),
        .inst_type_to_res_stn(inst_type_disp_to_res_stn),
        .Vi_to_res_stn(Vi_disp_to_res_stn),
        .Vj_to_res_stn(Vj_disp_to_res_stn),
        .Qi_to_res_stn(Qi_disp_to_res_stn),
        .Qj_to_res_stn(Qj_disp_to_res_stn),
        .imm_to_res_stn(imm_disp_to_res_stn),
        .pc_to_res_stn(pc_disp_to_res_stn),

        .valid_to_lsb(valid_disp_to_lsb),
        .alias_to_lsb(alias_disp_to_lsb),
        .inst_type_to_lsb(inst_type_disp_to_lsb),
        .Vi_to_lsb(Vi_disp_to_lsb),
        .Vj_to_lsb(Vj_disp_to_lsb),
        .Qi_to_lsb(Qi_disp_to_lsb),
        .Qj_to_lsb(Qj_disp_to_lsb),
        .imm_to_lsb(imm_disp_to_lsb),
        .pc_to_lsb(pc_disp_to_lsb),

        .valid_from_alu(valid_alu_to_cdb),
        .alias_from_alu(alias_alu_to_cdb),
        .result_from_alu(result_alu_to_cdb),

        .valid_from_lsb(valid_lsb_to_cdb),
        .alias_from_lsb(alias_lsb_to_cdb),
        .result_from_lsb(result_lsb_to_cdb)
    );

    // decoder
    decoder decode(
        .inst_id(data_disp_to_decoder),
        .opt(inst_type_decoder_to_disp),
        .rd(rd_decoder_to_disp),
        .rs1(rs1_decoder_to_disp),
        .rs2(rs2_decoder_to_disp),
        .imm(imm_decoder_to_disp),
        .is_load_store(is_load_store_decoder_to_disp),
        .is_btype(is_btype_decoder_to_disp)
    );

    // CDB
    // wire valid_lsb_to_rob;
    // wire [`ROB_RANGE] alias_lsb_to_rob;
    // wire [`DATA_RANGE] result_lsb_to_rob;

    wire commit_command_rob_to_lsb;
    wire [`ROB_RANGE] alias_rob_to_lsb;

    // CDB
    // wire valid_alu_to_rob;
    // wire [`ROB_RANGE] alias_alu_to_rob;
    // wire [`DATA_RANGE] result_alu_to_rob;

    wire really_jump_alu_to_rob;
    wire [`DATA_RANGE] real_pc_alu_to_rob;

    wire valid_rob_to_rf;
    wire [`REG_RANGE] reg_id_rob_to_rf;
    wire [`ROB_RANGE] alias_rob_to_rf;
    wire [`DATA_RANGE] result_rob_to_rf;

    ROB rob(
        .clk(clk_in),
        .rst(rst_in),
        .rdy(rdy_in),

        .rob_full(rob_is_full),
        .rollback(global_rollback),
        .rollback_pc(global_rollback_pc),

        .valid_from_lsb(valid_lsb_to_cdb),
        .alias_from_lsb(alias_lsb_to_cdb),
        .result_from_lsb(result_lsb_to_cdb),

        .commit_command_to_lsb(commit_command_rob_to_lsb),
        .alias_to_store(alias_rob_to_lsb),

        .valid_from_alu(valid_alu_to_cdb),
        .alias_from_alu(alias_alu_to_cdb),
        .result_from_alu(result_alu_to_cdb),

        .really_jump_from_alu(really_jump_alu_to_rob),
        .real_pc_from_alu(real_pc_alu_to_rob),

        .valid_from_disp(valid_disp_to_rob),
        .pc_from_disp(pc_disp_to_rob),
        .rd_from_disp(rd_disp_to_rob),
        .is_btype_from_disp(is_btype_disp_to_rob),
        .is_load_store_from_disp(is_load_store_disp_to_rob),
        .predicted_jump_from_disp(predicted_jump_disp_to_rob),
        .inst_type_from_disp(inst_type_disp_to_rob),

        .Qi_from_disp(Qi_disp_to_rob),
        .Qj_from_disp(Qj_disp_to_rob),
        .Vi_valid_to_disp(Vi_valid_rob_to_disp),
        .Vi_to_disp(Vi_rob_to_disp),
        .Vj_valid_to_disp(Vj_valid_rob_to_disp),
        .Vj_to_disp(Vj_rob_to_disp),
        .cur_rename_id_to_disp(cur_alias_rob_to_disp),

        .valid_to_reg_file(valid_rob_to_rf),
        .reg_id_to_reg_file(reg_id_rob_to_rf),
        .alias_to_reg_file(alias_rob_to_rf),
        .result_to_reg_file(result_rob_to_rf)
    );

    wire valid_res_stn_to_alu;
    wire [`OPT_RANGE] inst_type_res_stn_to_alu;
    wire [`ROB_RANGE] alias_res_stn_to_alu;
    wire [`DATA_RANGE] Vi_res_stn_to_alu;
    wire [`DATA_RANGE] Vj_res_stn_to_alu;
    wire [`DATA_RANGE] imm_res_stn_to_alu;
    wire [`DATA_RANGE] pc_res_stn_to_alu;

    // Reservation station
    reservation_station rs(
        .clk(clk_in),
        .rst(rst_in),
        .rdy(rdy_in),

        .rs_full(rs_is_full),

        .rollback_from_rob(global_rollback),

        .valid_from_disp(valid_disp_to_res_stn),
        .pc_from_disp(pc_disp_to_res_stn),
        .inst_type_from_disp(inst_type_disp_to_res_stn),
        .rd_from_disp(alias_disp_to_res_stn),
        .Qi_from_disp(Qi_disp_to_res_stn),
        .Qj_from_disp(Qj_disp_to_res_stn),
        .Vi_from_disp(Vi_disp_to_res_stn),
        .Vj_from_disp(Vj_disp_to_res_stn),
        .imm_from_disp(imm_disp_to_res_stn),

        .valid_from_alu(valid_alu_to_cdb),
        .alias_from_alu(alias_alu_to_cdb),
        .result_from_alu(result_alu_to_cdb),

        .valid_to_alu(valid_res_stn_to_alu),
        .inst_type_to_alu(inst_type_res_stn_to_alu),
        .alias_to_alu(alias_res_stn_to_alu),
        .Vi_to_alu(Vi_res_stn_to_alu),
        .Vj_to_alu(Vj_res_stn_to_alu),
        .imm_to_alu(imm_res_stn_to_alu),
        .pc_to_alu(pc_res_stn_to_alu),

        .valid_from_lsb(valid_lsb_to_cdb),
        .alias_from_lsb(alias_lsb_to_cdb),
        .result_from_lsb(result_lsb_to_cdb)
    );

    // ALU
    ALU alu(
        .opt(inst_type_res_stn_to_alu),
        .rs1(Vi_res_stn_to_alu),
        .rs2(Vj_res_stn_to_alu),
        .imm(imm_res_stn_to_alu),
        .pc(pc_res_stn_to_alu),
        .target_rob_index(alias_res_stn_to_alu),

        .result_valid(valid_alu_to_cdb),
        .res(result_alu_to_cdb),
        .target_rob_index_output(alias_alu_to_cdb),
        .pc_output(real_pc_alu_to_rob),
        .really_jump(really_jump_alu_to_rob)
    );

    // Load-store buffer
    LSB lsb(
        .clk(clk_in),
        .rst(rst_in),
        .rdy(rdy_in),

        .lsb_full(lsb_is_full),

        .commit_command_from_rob(commit_command_rob_to_lsb),
        .alias_to_store(alias_rob_to_lsb),

        .rollback_from_rob(global_rollback),

        .valid_from_disp(valid_disp_to_lsb),
        .pc_from_disp(pc_disp_to_lsb),
        .inst_type_from_disp(inst_type_disp_to_lsb),
        .rd_from_disp(alias_disp_to_lsb),
        .Qi_from_disp(Qi_disp_to_lsb),
        .Qj_from_disp(Qj_disp_to_lsb),
        .Vi_from_disp(Vi_disp_to_lsb),
        .Vj_from_disp(Vj_disp_to_lsb),
        .imm_from_disp(imm_disp_to_lsb),

        .valid_from_memctrl(valid_mem_ctrl_to_lsb),
        .data_from_memctrl(data_mem_ctrl_to_lsb),
        .valid_to_memctrl(valid_lsb_to_mem_ctrl),
        .addr_to_memctrl(addr_lsb_to_mem_ctrl),
        .data_to_memctrl(data_lsb_to_mem_ctrl),
        .inst_type_to_memctrl(inst_type_lsb_to_mem_ctrl),

        .valid_from_alu(valid_alu_to_cdb),
        .alias_from_alu(alias_alu_to_cdb),
        .result_from_alu(result_alu_to_cdb),

        .valid_to_rob(valid_lsb_to_cdb),
        .alias_to_rob(alias_lsb_to_cdb),
        .result_to_rob(result_lsb_to_cdb)
    );

    register_file registers(
        .clk(clk_in),
        .rst(rst_in),
        .rdy(rdy_in),

        .rollback(global_rollback),

        .rs1_from_disp(rs1_disp_to_rf),
        .rs2_from_disp(rs2_disp_to_rf),

        .Vi_to_disp(Vi_rf_to_disp),
        .Qi_to_disp(Qi_rf_to_disp),
        .Vj_to_disp(Vj_rf_to_disp),
        .Qj_to_disp(Qj_rf_to_disp),

        .renaming_valid(renaming_valid_disp_to_rf),
        .renaming_reg_id(renaming_reg_id_disp_to_rf),
        .renaming_alias(renaming_alias_disp_to_rf),

        .result_valid_from_rob(valid_rob_to_rf),
        .reg_id_from_rob(reg_id_rob_to_rf),
        .alias_from_rob(alias_rob_to_rf),
        .result_from_rob(result_rob_to_rf)
    );

endmodule