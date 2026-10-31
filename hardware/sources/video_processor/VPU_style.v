`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: VPU_style
// Description: 原图、灰度、二值、反色。伽马曲线已去掉。
//              插在色彩之后、缩放之前。参数在输入场同步上升沿锁存。
//              各模式延迟都是 3 拍，同步和坐标一起走。
//              亮度 Y = (R + 2G + B) >> 2。
//              模式 4 及以上按原图直通。style_gamma 保留端口，画面不再使用。
//////////////////////////////////////////////////////////////////////////////////

module VPU_style #(
    parameter                   GAMMA_FILE                  = "style_gamma.mem"
)(
    input   wire                clk                         ,
    input   wire                reset                       ,

    input   wire                style_disable               ,
    input   wire    [2:0]       style_mode                  ,
    input   wire    [7:0]       style_bin_th                ,
    input   wire    [7:0]       style_gamma                 ,

    input   wire                style_in_vsync              ,
    input   wire                style_in_hsync              ,
    input   wire                style_in_de                 ,
    input   wire    [12:0]      style_in_xcnt               ,
    input   wire    [12:0]      style_in_ycnt               ,
    input   wire    [23:0]      style_in_rgb                ,

    output  reg                 style_out_vsync             ,
    output  reg                 style_out_hsync             ,
    output  reg                 style_out_de                ,
    output  reg     [12:0]      style_out_xcnt              ,
    output  reg     [12:0]      style_out_ycnt              ,
    output  reg     [23:0]      style_out_rgb
);

localparam                      MODE_PASS                   = 3'd0;
localparam                      MODE_GRAY                   = 3'd1;
localparam                      MODE_BIN                    = 3'd2;
localparam                      MODE_INV                    = 3'd3;

reg                             vsync_d                     ;
reg                             disable_l                   ;
reg             [2:0]           mode_l                      ;
reg             [7:0]           bin_l                       ;

reg                             p_vs                        ;
reg                             p_hs                        ;
reg                             p_de                        ;
reg             [12:0]          p_x                         ;
reg             [12:0]          p_y                         ;
reg             [23:0]          p_rgb                       ;
reg                             h_vs                        ;
reg                             h_hs                        ;
reg                             h_de                        ;
reg             [12:0]          h_x                         ;
reg             [12:0]          h_y                         ;
reg             [23:0]          h_rgb                       ;

wire            [7:0]           y_h                         ;
wire            [23:0]          gray_rgb                    ;
wire            [23:0]          bin_rgb                     ;
wire            [23:0]          inv_rgb                     ;
wire            [23:0]          effect                      ;

function [7:0] luma8;
    input [23:0] rgb;
    reg   [9:0]  sum;
    begin
        sum   = rgb[23:16] + {rgb[15:8], 1'b0} + rgb[7:0];
        luma8 = sum[9:2];
    end
endfunction

always @(posedge clk) begin
    if(reset) begin
        vsync_d   <= 1'b0;
        disable_l <= 1'b0;
        mode_l    <= MODE_PASS;
        bin_l     <= 8'd128;
    end
    else begin
        vsync_d <= style_in_vsync;
        if(style_in_vsync && !vsync_d) begin
            disable_l <= style_disable;
            mode_l    <= style_mode;
            bin_l     <= style_bin_th;
        end
    end
end

always @(posedge clk) begin
    if(reset) begin
        p_vs  <= 1'b0;
        p_hs  <= 1'b0;
        p_de  <= 1'b0;
        p_x   <= 13'd0;
        p_y   <= 13'd0;
        p_rgb <= 24'd0;
        h_vs  <= 1'b0;
        h_hs  <= 1'b0;
        h_de  <= 1'b0;
        h_x   <= 13'd0;
        h_y   <= 13'd0;
        h_rgb <= 24'd0;
    end
    else begin
        p_vs  <= style_in_vsync;
        p_hs  <= style_in_hsync;
        p_de  <= style_in_de;
        p_x   <= style_in_xcnt;
        p_y   <= style_in_ycnt;
        p_rgb <= style_in_rgb;
        h_vs  <= p_vs;
        h_hs  <= p_hs;
        h_de  <= p_de;
        h_x   <= p_x;
        h_y   <= p_y;
        h_rgb <= p_rgb;
    end
end

assign y_h       = luma8(h_rgb);
assign gray_rgb  = {y_h, y_h, y_h};
assign bin_rgb   = (y_h >= bin_l) ? 24'hFFFFFF : 24'h000000;
assign inv_rgb   = {8'd255 - h_rgb[23:16], 8'd255 - h_rgb[15:8], 8'd255 - h_rgb[7:0]};
assign effect    = (!h_de || disable_l || (mode_l == MODE_PASS)) ? h_rgb :
                   (mode_l == MODE_GRAY)  ? gray_rgb  :
                   (mode_l == MODE_BIN)   ? bin_rgb   :
                   (mode_l == MODE_INV)   ? inv_rgb   : h_rgb;

always @(posedge clk) begin
    if(reset) begin
        style_out_vsync <= 1'b0;
        style_out_hsync <= 1'b0;
        style_out_de    <= 1'b0;
        style_out_xcnt  <= 13'd0;
        style_out_ycnt  <= 13'd0;
        style_out_rgb   <= 24'd0;
    end
    else begin
        style_out_vsync <= h_vs;
        style_out_hsync <= h_hs;
        style_out_de    <= h_de;
        style_out_xcnt  <= h_x;
        style_out_ycnt  <= h_y;
        style_out_rgb   <= effect;
    end
end

endmodule
