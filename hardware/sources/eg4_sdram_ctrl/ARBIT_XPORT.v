`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// 
// Create Date: 2024/12/27 11:58:01
// Design Name: 
// Module Name: ARBIT
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ARBIT_XPORT#(
    parameter       PORT_NUM = 5
)(
    input   wire                    clk             ,
    input   wire                    reset           ,

    input   wire                    init_done       ,

    input   wire    [PORT_NUM-1:0]  i_request       ,
    input   wire    [PORT_NUM-1:0]  i_request_end   ,
    output  wire    [PORT_NUM-1:0]  o_request_allow   
);

reg                     init_done_r         ;
reg     [3:0]           port_roll_poling    ;//端口轮询
reg     [PORT_NUM-1:0]  request_hold        ;
wire    [15:0]          next_flag           ;

always@(posedge clk) begin
    init_done_r <= init_done;
end

always@(posedge clk) begin
    if(reset | !init_done_r) begin
        port_roll_poling <= 4'd0;
    end
    else begin
        case(port_roll_poling)
            4'h0    : begin port_roll_poling <= next_flag[00] ? (port_roll_poling >= PORT_NUM - 4'd1 ? 4'h0 : port_roll_poling + 1'b1) : port_roll_poling   ;end
            4'h1    : begin port_roll_poling <= next_flag[01] ? (port_roll_poling >= PORT_NUM - 4'd1 ? 4'h0 : port_roll_poling + 1'b1) : port_roll_poling   ;end
            4'h2    : begin port_roll_poling <= next_flag[02] ? (port_roll_poling >= PORT_NUM - 4'd1 ? 4'h0 : port_roll_poling + 1'b1) : port_roll_poling   ;end
            4'h3    : begin port_roll_poling <= next_flag[03] ? (port_roll_poling >= PORT_NUM - 4'd1 ? 4'h0 : port_roll_poling + 1'b1) : port_roll_poling   ;end
            4'h4    : begin port_roll_poling <= next_flag[04] ? (port_roll_poling >= PORT_NUM - 4'd1 ? 4'h0 : port_roll_poling + 1'b1) : port_roll_poling   ;end
            4'h5    : begin port_roll_poling <= next_flag[05] ? (port_roll_poling >= PORT_NUM - 4'd1 ? 4'h0 : port_roll_poling + 1'b1) : port_roll_poling   ;end
            4'h6    : begin port_roll_poling <= next_flag[06] ? (port_roll_poling >= PORT_NUM - 4'd1 ? 4'h0 : port_roll_poling + 1'b1) : port_roll_poling   ;end
            4'h7    : begin port_roll_poling <= next_flag[07] ? (port_roll_poling >= PORT_NUM - 4'd1 ? 4'h0 : port_roll_poling + 1'b1) : port_roll_poling   ;end
            4'h8    : begin port_roll_poling <= next_flag[08] ? (port_roll_poling >= PORT_NUM - 4'd1 ? 4'h0 : port_roll_poling + 1'b1) : port_roll_poling   ;end
            4'h9    : begin port_roll_poling <= next_flag[09] ? (port_roll_poling >= PORT_NUM - 4'd1 ? 4'h0 : port_roll_poling + 1'b1) : port_roll_poling   ;end
            4'hA    : begin port_roll_poling <= next_flag[10] ? (port_roll_poling >= PORT_NUM - 4'd1 ? 4'h0 : port_roll_poling + 1'b1) : port_roll_poling   ;end
            4'hB    : begin port_roll_poling <= next_flag[11] ? (port_roll_poling >= PORT_NUM - 4'd1 ? 4'h0 : port_roll_poling + 1'b1) : port_roll_poling   ;end
            4'hC    : begin port_roll_poling <= next_flag[12] ? (port_roll_poling >= PORT_NUM - 4'd1 ? 4'h0 : port_roll_poling + 1'b1) : port_roll_poling   ;end
            4'hD    : begin port_roll_poling <= next_flag[13] ? (port_roll_poling >= PORT_NUM - 4'd1 ? 4'h0 : port_roll_poling + 1'b1) : port_roll_poling   ;end
            4'hE    : begin port_roll_poling <= next_flag[14] ? (port_roll_poling >= PORT_NUM - 4'd1 ? 4'h0 : port_roll_poling + 1'b1) : port_roll_poling   ;end
            4'hF    : begin port_roll_poling <= next_flag[15] ? (port_roll_poling >= PORT_NUM - 4'd1 ? 4'h0 : port_roll_poling + 1'b1) : port_roll_poling   ;end
            default : begin port_roll_poling <= 4'h0                                                                                                        ;end
        endcase
    end
end

genvar i;
generate 
    for(i = 0;i < PORT_NUM;i = i + 1) begin 

        assign next_flag[i] = (!(request_hold[i] || i_request[i])) || (request_hold[i] && i_request_end[i]);

        always@(posedge clk) begin
            if(reset) begin
                request_hold[i] <= 1'b0;
            end
            else if(i_request_end[i]) begin 
                request_hold[i] <= 1'b0; 
            end
            else if(!request_hold[i] && (port_roll_poling == i) && i_request[i]) begin 
                request_hold[i] <= 1'b1; 
            end
        end

        assign o_request_allow[i] = request_hold[i];
    end

endgenerate

endmodule
