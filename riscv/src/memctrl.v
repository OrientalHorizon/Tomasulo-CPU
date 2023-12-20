`include "utils.v"

`define IDLE 0
`define STORE_PROCESSING 1
`define LOAD_PROCESSING 2
`define FETCH_PROCESSING 3
`define STALL 3 // Maybe waiting for RAM

`define WRITE 0
`define READ 1

module MemCtrl (
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
    input  wire [6:0] inst_type_from_lsb,
    output reg  valid_to_lsb,
    output reg  [`DATA_RANGE] data_to_lsb,

    input wire  uart_full,
    input wire  [7:0] data_from_ram,
    output reg  write_or_read, // write = 0, read = 1
    output reg  [`ADDR_RANGE] addr_to_ram,
    output reg  [7:0] data_to_ram
);  
    reg [2:0] status;
    reg [15:0] counter;
    reg [2:0] tot_bytes;
    always @(posedge clk) begin
        if (rst) begin
            valid_to_icache <= 1'b0;
            valid_to_lsb <= 1'b0;
            
            data_to_icache <= 32'b0;
            data_to_lsb <= 32'b0;
            addr_to_ram <= 32'b0;
            write_or_read <= `READ; // ?
        end
        else if (!rdy) begin end
        else if (uart_full) begin end
        else begin
            if (inst_type_from_lsb == `LW || inst_type_from_lsb == `LH || inst_type_from_lsb == `LB) begin
                write_or_read <= `READ;
            end
            else begin
                write_or_read <= `WRITE;
            end

            if (status == `IDLE) begin
                // 优先级：写 > 读 > IFetch
                if (valid_from_lsb && write_or_read == `WRITE) begin
                    counter <= 0;
                    status <= `STORE_PROCESSING;
                    addr_to_ram <= addr_from_lsb;
                    if (inst_type_from_lsb == `SW) begin
                        tot_bytes <= 3'b11;
                    end
                    else if (inst_type_from_lsb == `SH) begin
                        tot_bytes <= 3'b10;
                    end
                    else if (inst_type_from_lsb == `SB) begin
                        tot_bytes <= 3'b01;
                    end
                    else begin
                        
                    end
                end
                else if (valid_from_lsb && write_or_read == `READ) begin
                    counter <= 0;
                    status <= `LOAD_PROCESSING;
                    addr_to_ram <= addr_from_lsb;
                    if (inst_type_from_lsb == `LW) begin
                        tot_bytes <= 3'b11;
                    end
                    else if (inst_type_from_lsb == `LH) begin
                        tot_bytes <= 3'b10;
                    end
                    else if (inst_type_from_lsb == `LB) begin
                        tot_bytes <= 3'b01;
                    end
                    else begin
                        
                    end
                end
                else if (valid_from_icache) begin
                    counter <= 0;
                    status <= `FETCH_PROCESSING;
                    addr_to_ram <= addr_from_icache;
                end
            end

            if (status == `STORE_PROCESSING && !uart_full) begin
                case (counter)
                    16'b0: data_to_ram <= data_from_lsb[7:0];
                    16'b1: data_to_ram <= data_from_lsb[15:8];
                    16'b10: data_to_ram <= data_from_lsb[23:16];
                    16'b11: data_to_ram <= data_from_lsb[31:24];
                endcase

                if (counter == tot_bytes) begin 
                    // 如果 -1 的话 data_to_ram 和 addr_to_ram 会被同时赋值，到时候会存到地址 0
                    // 准备停机一周期
                    status <= `STALL;
                    valid_to_lsb <= 1'b1;
                    addr_to_ram <= 0;
                    write_or_read <= `READ;
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

            if (status <= `STALL) begin
                status <= `IDLE;
                write_or_read <= `READ;
                valid_to_icache <= 0;
                valid_to_lsb <= 0;
            end

        end
    end

endmodule