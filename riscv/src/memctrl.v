`include "utils.v"

`define IDLE 0
`define STORE_PROCESSING 1
`define LOAD_PROCESSING 2
`define FETCH_PROCESSING 3
`define STALL 4 // Maybe waiting for RAM

`define WRITE 1
`define READ 0

module mem_ctrl (
    input  wire clk,
    input  wire rst,
    input  wire rdy,

    // ICache 在离内存更远的位置。
    input  wire valid_from_icache,
    input  wire [`ADDR_RANGE] addr_from_icache,
    output reg  valid_to_icache,
    output reg  [`DATA_RANGE] data_to_icache,

    input  wire valid_from_lsb,
    input  wire [`ADDR_RANGE] addr_from_lsb,
    input  wire [`DATA_RANGE] data_from_lsb,
    input  wire [`OPT_RANGE] inst_type_from_lsb,
    output reg  valid_to_lsb,
    output reg  [`DATA_RANGE] data_to_lsb,

    input wire  uart_full,
    input wire  [7:0] data_from_ram,
    output reg  write_or_read, // write = 1, read = 0
    output reg  [`ADDR_RANGE] addr_to_ram,
    output reg  [7:0] data_to_ram
);  
    reg [3:0] status;
    reg [15:0] counter;
    reg [2:0] tot_bytes;
    reg [31:0] clk_cnt = 0;
    reg local_is_write;
    always @(posedge clk) begin
        clk_cnt = clk_cnt + 1;
        if (rst) begin
            valid_to_icache <= 1'b0;
            valid_to_lsb <= 1'b0;
            
            data_to_icache <= 32'b0;
            data_to_lsb <= 32'b0;
            addr_to_ram <= 32'b0;
            write_or_read <= `READ; // ?
            local_is_write <= 1'b0;
            status <= `IDLE;
        end
        else if (!rdy) begin end
        else if (uart_full) begin end
        else begin
            if (valid_from_lsb && (inst_type_from_lsb == `SW || inst_type_from_lsb == `SH || inst_type_from_lsb == `SB)) begin
                local_is_write <= 1'b1;
            end
            else if (valid_from_lsb) begin
                local_is_write <= 1'b0;
            end

            if (status == `IDLE) begin
                // 优先级：写 > 读 > IFetch
                if (valid_from_lsb && local_is_write == `WRITE) begin
                    counter <= 0;
                    status <= `STORE_PROCESSING;
                    addr_to_ram <= addr_from_lsb - 1;
                    // 这里不能提前赋 write_or_read 为 1，否则它就直接开始写了
                    if (inst_type_from_lsb == `SW) begin
                        tot_bytes <= 4; // 之前怎么想的写成 3？？？
                    end
                    else if (inst_type_from_lsb == `SH) begin
                        tot_bytes <= 2;
                    end
                    else if (inst_type_from_lsb == `SB) begin
                        tot_bytes <= 1;
                    end
                    else begin
                        
                    end
                end
                else if (valid_from_lsb && local_is_write == `READ) begin
                    counter <= 0;
                    status <= `LOAD_PROCESSING;
                    addr_to_ram <= addr_from_lsb;
                    if (inst_type_from_lsb == `LW) begin
                        tot_bytes <= 4;
                    end
                    else if (inst_type_from_lsb == `LH || inst_type_from_lsb == `LHU) begin
                        tot_bytes <= 2;
                    end
                    else if (inst_type_from_lsb == `LB || inst_type_from_lsb == `LBU) begin
                        tot_bytes <= 1;
                    end
                    else begin
                        
                    end
                end
                else if (valid_from_icache) begin
                    // $display("current clock = %d", clk_cnt);
                    // $display("IDLE && valid from icache");
                    counter <= 0;
                    status <= `FETCH_PROCESSING;
                    addr_to_ram <= addr_from_icache;
                    tot_bytes <= 4;
                end
            end
            if (status == `STORE_PROCESSING && !uart_full) begin
                case (counter)
                    16'b0: data_to_ram <= data_from_lsb[7:0];
                    16'b1: data_to_ram <= data_from_lsb[15:8];
                    16'b10: data_to_ram <= data_from_lsb[23:16];
                    16'b11: data_to_ram <= data_from_lsb[31:24];
                endcase

                write_or_read <= `WRITE;

                if (counter == tot_bytes) begin 
                    // 如果 -1 的话 data_to_ram 和 addr_to_ram 会被同时赋值，到时候会存到地址 0
                    // 准备停机一周期
                    status <= `STALL;
                    valid_to_lsb <= 1'b1;
                    addr_to_ram <= 0;
                    // write_or_read <= `READ; 还没到时候
                end
                else begin
                    counter <= counter + 1;
                    addr_to_ram <= addr_to_ram + 1;
                end
            end
            if (status == `LOAD_PROCESSING) begin
                case (counter)
                    16'h1: data_to_lsb[7:0] <= data_from_ram;
                    16'h2: data_to_lsb[15:8] <= data_from_ram;
                    16'h3: data_to_lsb[23:16] <= data_from_ram;
                    16'h4: data_to_lsb[31:24] <= data_from_ram;
                endcase

                if (counter == tot_bytes + 1) begin
                    addr_to_ram <= 0;

                    // sign extend
                    if (inst_type_from_lsb == `LB) begin
                        data_to_lsb <= {{24{data_to_lsb[7]}}, data_to_lsb[7:0]};
                    end
                    else if (inst_type_from_lsb == `LH) begin
                        data_to_lsb <= {{16{data_to_lsb[15]}}, data_to_lsb[15:0]};
                    end

                    valid_to_lsb <= 1'b1;
                    status <= `STALL;
                end
                else begin
                    counter <= counter + 1;
                    addr_to_ram <= addr_to_ram + 1;
                end
            end
            if (status == `FETCH_PROCESSING) begin
                // $display("current clock = %d", clk_cnt);
                // $display("fetching: counter = %d", counter);
                case (counter)
                    16'h1: data_to_icache[7:0] <= data_from_ram;
                    16'h2: data_to_icache[15:8] <= data_from_ram;
                    16'h3: data_to_icache[23:16] <= data_from_ram;
                    16'h4: data_to_icache[31:24] <= data_from_ram;
                endcase

                if (counter == tot_bytes) begin
                    addr_to_ram <= 0;
                    valid_to_icache <= 1'b1;
                    status <= `STALL;
                end
                else begin
                    counter <= counter + 1;
                    addr_to_ram <= addr_to_ram + 1;
                end
            end
            else if (status == `STALL) begin // 写成 <= 了，无语
                status <= `IDLE;
                write_or_read <= `READ;
                valid_to_icache <= 0;
                valid_to_lsb <= 0;
            end

        end
    end

endmodule