`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// ███╗   ███╗██╗   ██╗██╗  ██╗ █████╗ ███╗   ██╗
// ████╗ ████║██║   ██║██║  ██║██╔══██╗████╗  ██║
// ██╔████╔██║██║   ██║███████║███████║██╔██╗ ██║
// ██║╚██╔╝██║██║   ██║██╔══██║██╔══██║██║╚██╗██║
// ██║ ╚═╝ ██║╚██████╔╝██║  ██║██║  ██║██║ ╚████║
// ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝
// Create Date: 2026/10/16 11:35:00
// Design Name: 
// Module Name: key_filter
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


module key_filter #(
    parameter                   CLK_FREQ                    = 50_000_000
)(
    input   wire                sys_clk                     ,
    input   wire                sys_rst                     ,
    input   wire                key_in                      ,
    output  reg                 key_flag
);
localparam                      CNT_MAX                     = CLK_FREQ / 50 - 1;//20ms
localparam                      CNT_W                       = $clog2(CNT_MAX + 1);

reg     [CNT_W-1:0]             cnt_20ms                    ;

always@(posedge sys_clk or posedge sys_rst) begin
    if(sys_rst) begin
        cnt_20ms <= {CNT_W{1'b0}};
    end
    else if(key_in == 1'b1) begin
        cnt_20ms <= {CNT_W{1'b0}};
    end
    else if(cnt_20ms == CNT_MAX && key_in == 1'b0) begin
        cnt_20ms <= cnt_20ms;
    end
    else begin
        cnt_20ms <= cnt_20ms + 1'b1;
    end
end


always@(posedge sys_clk or posedge sys_rst) begin
    if(sys_rst) begin
        key_flag <= 1'b0;
    end
    else if(cnt_20ms == CNT_MAX - 1'b1) begin
        key_flag <= 1'b1;
    end
    else begin
        key_flag <= 1'b0;
    end
end

endmodule
