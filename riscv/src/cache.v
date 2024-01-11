`include "utils.v"

`define STALL 1'b0
`define AVAILABLE 1'b1
`define ICACHE_ENTRIES 256

`define INDEX_RANGE 9:2
`define TAG_RANGE 17:10

module ICache(
    input  wire clk,
    input  wire rst,
    input  wire rdy,

    input  wire valid_from_ifetch,
    input  wire [`DATA_RANGE] pc_from_ifetch,
    output wire valid_to_ifetch,
    output wire [`DATA_RANGE] data_to_ifetch,

    input  wire valid_from_memctrl,
    input  wire [`DATA_RANGE] data_from_memctrl,
    output reg  valid_to_memctrl,
    output reg  [`ADDR_RANGE] addr_to_memctrl
);
// 17:10 是 tag，9:2 是 index，pc 的后两位没有意义
    reg status;
    // reg [15:0] counter;

    // reg [`REAL_ADDR_RANGE] storage [255:0]; 咋想的？？？？？？？指令不是值吗
    reg [`DATA_RANGE] storage [255:0];
    reg valid [255:0];
    reg [`TAG_RANGE] tag [255:0];

    wire hit = valid[pc_from_ifetch[`INDEX_RANGE]] && tag[pc_from_ifetch[`INDEX_RANGE]] == pc_from_ifetch[`TAG_RANGE];
    assign valid_to_ifetch = hit || (valid_from_memctrl && addr_to_memctrl == pc_from_ifetch);
    assign data_to_ifetch = hit ? storage[pc_from_ifetch[`INDEX_RANGE]] : data_from_memctrl; // TODO MARK

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            status <= `AVAILABLE;
            // valid_to_ifetch <= 1'b0;
            valid_to_memctrl <= 1'b0;
            for (i = 0; i < 256; i = i + 1) begin
                valid[i] <= 1'b0;
                tag[i] <= 0;
                storage[i] <= 0;
            end
        end

        else if (~rdy) begin end

        else begin
            if (status == `AVAILABLE) begin
                if (~hit) begin
                    status <= `STALL;
                    valid_to_memctrl <= 1'b1;
                    addr_to_memctrl <= pc_from_ifetch;
                end
            end
            else begin // `STALL
                if (valid_from_memctrl) begin
                    valid_to_memctrl <= 1'b0;
                    status <= `AVAILABLE;
                    valid[addr_to_memctrl[`INDEX_RANGE]] <= 1'b1;
                    tag[addr_to_memctrl[`INDEX_RANGE]] <= addr_to_memctrl[`TAG_RANGE];
                    storage[addr_to_memctrl[`INDEX_RANGE]] <= data_from_memctrl;
                end
            end
        end
    end


endmodule