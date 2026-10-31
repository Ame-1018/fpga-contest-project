`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Create Date: 2026/10/08 09:21:17
// Design Name: 
// Module Name: HDMI_VIDEO_TO_AXI
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

module HDMI_VIDEO_TO_AXI(
    input   wire                clk                     ,
    input   wire                reset                   ,

    input   wire                in_hdmi_locked          ,

    input   wire                in_hdmi_vsync           ,
    input   wire                in_hdmi_hsync           ,
    input   wire                in_hdmi_de              ,
    input   wire    [23:0]      in_hdmi_data            ,

    input   wire                hdmi_axis_s_ready       ,

    output  reg                 hdmi_axis_s_user        ,
    output  reg                 hdmi_axis_s_valid       ,
    output  reg                 hdmi_axis_s_last        ,
    output  reg     [23:0]      hdmi_axis_s_data                    
);

reg     [2:0]                   in_hdmi_locked_r3       ;

reg     [2:0]                   hdmi_vsync_r3           ;
reg     [2:0]                   hdmi_hsync_r3           ;
reg     [2:0]                   hdmi_de_r3              ;
reg     [23:0]                  hdmi_data_r3    [3:0]   ;

wire                            hdmi_vsync_pos          ;
reg                             hdmi_first_flag         ;

reg                             hdmi_de_one_start       ;

wire                            hdmi_de_pos             ;
wire                            hdmi_de_neg             ;

reg                             hdmi_de_pos_r           ;
reg                             hdmi_de_neg_r           ;


always@(posedge clk) begin
    in_hdmi_locked_r3 <= {in_hdmi_locked_r3[1:0],in_hdmi_locked};
end


always@(posedge clk) begin
    hdmi_vsync_r3 <= {hdmi_vsync_r3[1:0],in_hdmi_vsync};
    hdmi_hsync_r3 <= {hdmi_hsync_r3[1:0],in_hdmi_hsync};
    hdmi_de_r3 <= {hdmi_de_r3[1:0],in_hdmi_de};
end

always@(posedge clk) begin
    hdmi_data_r3[0] <= in_hdmi_data;
    hdmi_data_r3[1] <= hdmi_data_r3[0];
    hdmi_data_r3[2] <= hdmi_data_r3[1];
end

assign hdmi_vsync_pos = hdmi_vsync_r3[0] & !hdmi_vsync_r3[1];
assign hdmi_de_pos = hdmi_de_r3[0] & !hdmi_de_r3[1];
assign hdmi_de_neg = !hdmi_de_r3[0] & hdmi_de_r3[1];

always@(posedge clk) begin
    hdmi_de_pos_r <= hdmi_de_pos;
    hdmi_de_neg_r <= hdmi_de_neg;
end

always@(posedge clk) begin
    if(reset) begin
        hdmi_first_flag <= 1'b0;
    end
    else if(hdmi_de_pos) begin
        hdmi_first_flag <= 1'b0;
    end
    else if(hdmi_vsync_pos) begin
        hdmi_first_flag <= 1'b1;
    end

    hdmi_de_one_start <= hdmi_first_flag;
end

/*----------------------------------------------------------*/

always@(posedge clk) begin
    hdmi_axis_s_user  <= hdmi_de_r3[1] & hdmi_de_one_start;
    hdmi_axis_s_valid <= hdmi_de_r3[1];
    hdmi_axis_s_last  <= hdmi_de_r3[1] & hdmi_de_neg;
    hdmi_axis_s_data  <= hdmi_de_r3[1] & in_hdmi_locked_r3[2] ? hdmi_data_r3[1] : 24'd0;
end

endmodule
