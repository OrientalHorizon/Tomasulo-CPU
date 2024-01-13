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
    wire local_is_write = valid_from_lsb && (inst_type_from_lsb == `SW || inst_type_from_lsb == `SH || inst_type_from_lsb == `SB);
    always @(posedge clk) begin
        clk_cnt = clk_cnt + 1;
        if (rst) begin
            valid_to_icache <= 1'b0;
            valid_to_lsb <= 1'b0;
            
            data_to_icache <= 32'b0;
            data_to_lsb <= 32'b0;
            addr_to_ram <= 32'b0;
            write_or_read <= `READ; // 是 write 的话内存直接开始写了，这是很危险的
            status <= `IDLE;
        end
        else if (!rdy) begin end
        else if (uart_full) begin end
        else begin
            // 同学你好，我是傻逼！！！！！！！！！！！！
            // 阻塞赋值需要下一周期才能实现！！！
            // if (valid_from_lsb && (inst_type_from_lsb == `SW || inst_type_from_lsb == `SH || inst_type_from_lsb == `SB)) begin
            //     local_is_write <= `WRITE;
            // end
            // else begin
            //     local_is_write <= `READ;
            // end

            if (status == `IDLE) begin
                // 优先级：写 > 读 > IFetch
                valid_to_icache <= 1'b0;
                valid_to_lsb <= 1'b0;
                if (valid_from_lsb && local_is_write == `WRITE) begin
                    counter <= 0;
                    status <= `STORE_PROCESSING;
                    // for testing
                    // addr_to_ram <= addr_from_lsb - 1;

                    // addr_to_ram <= addr_from_lsb;

                    // - 1 是因为下面循环的时候会统一 + 1
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
                    data_to_lsb <= 0;
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
                    counter <= 0;
                    status <= `FETCH_PROCESSING;
                    addr_to_ram <= addr_from_icache;
                    tot_bytes <= 4;
                end
            end
            if (status == `STORE_PROCESSING && ((!uart_full) || (addr_from_lsb != 32'h30000 && addr_from_lsb != 32'h30004))) begin // TODO: 只有往 30000 多写的时候 io_buffer_full 才会有影响
            // if (status == `STORE_PROCESSING) begin // Simulation only
                case (counter)
                    16'b0: data_to_ram <= data_from_lsb[7:0];
                    16'b1: data_to_ram <= data_from_lsb[15:8];
                    16'b10: data_to_ram <= data_from_lsb[23:16];
                    16'b11: data_to_ram <= data_from_lsb[31:24];
                endcase

                // write_or_read <= `WRITE;

                if (counter == tot_bytes) begin
                    // 如果 -1 的话 data_to_ram 和 addr_to_ram 会被同时赋值，到时候会存到地址 0
                    // 准备停机一周期
                    status <= `STALL;
                    valid_to_lsb <= 1'b1;
                    addr_to_ram <= 0;
                    write_or_read <= `READ;
                end
                else begin
                    write_or_read <= `WRITE;
                    counter <= counter + 1;
                    addr_to_ram <= (counter == 0) ? addr_from_lsb : addr_to_ram + 1;
                end
            end
            if (status == `LOAD_PROCESSING) begin
                // fix: 假设只读一个字节，counter = 16'h2 的时候 RAM 也可能传值进来，导致多赋值
                if (counter <= tot_bytes) begin
                    case (counter)
                        16'h1: data_to_lsb[7:0] <= data_from_ram;
                        16'h2: data_to_lsb[15:8] <= data_from_ram;
                        16'h3: data_to_lsb[23:16] <= data_from_ram;
                        16'h4: data_to_lsb[31:24] <= data_from_ram;
                    endcase
                end

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
            if (status == `STALL) begin // 写成 <= 了，无语
                status <= `IDLE;
                write_or_read <= `READ;
                valid_to_icache <= 0;
                valid_to_lsb <= 0;
            end

        end
    end

endmodule