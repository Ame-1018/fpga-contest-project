`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Create Date: 2026/10/19 16:52:00
// Design Name: 
// Module Name: VPU_display_effect
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 亮度、对比度、色温、色调。四个口都是 0～255，128 为原始画面。
//              场同步上升沿锁存。对比度与通道增益在消隐里逐位相乘，
//              像素偏差与增益仍用 dsp_mul_s11x8。
// 
// Dependencies: dsp_mul_s11x8
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: 通道增益先寄存。像素偏差打一拍后再进乘法，
//              像素积再寄存，饱和结果再打一拍。PIX_LAT = 3。
//              disable=1 时按该拍数透传。
//              x 从 0 起且小于宽度、y 从 1 到高度为有效区，区外输出黑。
// 
//////////////////////////////////////////////////////////////////////////////////

module VPU_display_effect(
    input   wire                clk                         ,
    input   wire                reset                       ,

    input   wire    [12:0]      dis_eff_valid_width         ,
    input   wire    [12:0]      dis_eff_valid_height        ,

    input   wire                dis_eff_disable             ,

    input   wire    [7:0]       lumi_set_data               ,
    input   wire    [7:0]       contrast_set_data           ,
    input   wire    [7:0]       temp_set_data               ,
    input   wire    [7:0]       tint_set_data               ,

    input   wire                dis_eff_in_vsync            ,
    input   wire                dis_eff_in_hsync            ,
    input   wire                dis_eff_in_de               ,
    input   wire    [12:0]      dis_eff_in_xcnt             ,
    input   wire    [12:0]      dis_eff_in_ycnt             ,
    input   wire    [23:0]      dis_eff_in_rgb              ,

    output  wire                dis_eff_out_vsync           ,
    output  wire                dis_eff_out_hsync           ,
    output  wire                dis_eff_out_de              ,
    output  wire    [12:0]      dis_eff_out_xcnt            ,
    output  wire    [12:0]      dis_eff_out_ycnt            ,
    output  wire    [23:0]      dis_eff_out_rgb             
);

localparam                      PIX_LAT                     = 3;

reg                             vsync_d                     ;
reg             [7:0]           lumi_l                      ;
reg             [7:0]           contrast_l                  ;
reg             [7:0]           temp_l                      ;
reg             [7:0]           tint_l                      ;

always@(posedge clk) begin
    if(reset) begin
        vsync_d    <= 1'b0;
        lumi_l     <= 8'd128;
        contrast_l <= 8'd128;
        temp_l     <= 8'd128;
        tint_l     <= 8'd128;
    end
    else begin
        vsync_d <= dis_eff_in_vsync;
        if(dis_eff_in_vsync && !vsync_d) begin
            lumi_l     <= lumi_set_data;
            contrast_l <= contrast_set_data;
            temp_l     <= temp_set_data;
            tint_l     <= tint_set_data;
        end
    end
end

wire signed     [8:0]           lumi_in_s                   ;
wire signed     [8:0]           lumi_s                      ;
wire            [8:0]           contrast_q8                 ;
wire signed     [8:0]           temp_in_s                   ;
wire signed     [8:0]           tint_in_s                   ;
wire signed     [8:0]           temp_delta                  ;
wire signed     [8:0]           tint_delta                  ;
wire signed     [8:0]           temp_s                      ;
wire signed     [8:0]           tint_s                      ;
wire signed     [8:0]           tint_half                   ;
wire signed     [9:0]           temp_ext                    ;
wire signed     [9:0]           tint_ext                    ;
wire signed     [9:0]           half_ext                    ;
wire signed     [9:0]           gain_r_s                    ;
wire signed     [9:0]           gain_g_s                    ;
wire signed     [9:0]           gain_b_s                    ;
wire            [8:0]           gain_r                      ;
wire            [8:0]           gain_g                      ;
wire            [8:0]           gain_b                      ;

assign lumi_in_s   = {1'b0, lumi_l};
assign temp_in_s   = {1'b0, temp_l};
assign tint_in_s   = {1'b0, tint_l};
assign lumi_s      = lumi_in_s - 9'sd128;
assign contrast_q8 = {contrast_l, 1'b0};
assign temp_delta  = temp_in_s - 9'sd128;
assign tint_delta  = tint_in_s - 9'sd128;
assign temp_s      = temp_delta >>> 1;
assign tint_s      = tint_delta >>> 1;
assign tint_half   = tint_s >>> 1;
assign temp_ext    = {{1{temp_s[8]}}, temp_s};
assign tint_ext    = {{1{tint_s[8]}}, tint_s};
assign half_ext    = {{1{tint_half[8]}}, tint_half};
assign gain_r_s    = 10'sd256 + temp_ext - half_ext;
assign gain_g_s    = 10'sd256 + tint_ext;
assign gain_b_s    = 10'sd256 - temp_ext - half_ext;
assign gain_r      = gain_r_s[8:0];
assign gain_g      = gain_g_s[8:0];
assign gain_b      = gain_b_s[8:0];

reg             [9:0]           k_r_q                       ;
reg             [9:0]           k_g_q                       ;
reg             [9:0]           k_b_q                       ;
reg             [23:0]          proc_rgb_q                  ;
reg                             coef_arm                    ;
reg                             coef_run                    ;
reg             [1:0]           coef_ch                     ;
reg             [3:0]           coef_bit                    ;
reg             [18:0]          coef_acc                    ;
reg             [18:0]          coef_a                      ;
reg             [18:0]          coef_b                      ;
reg             [18:0]          coef_sum                    ;
wire            [18:0]          coef_add                    ;
wire            [9:0]           coef_part                   ;
assign coef_add  = coef_acc + (coef_a[0] ? coef_b : 19'd0);
assign coef_part = coef_add[17:8];

// 增益一场才变一次。消隐里逐位乘完再更新 k，像素通路看不到这次乘法。
always@(posedge clk) begin
    if(reset) begin
        coef_arm  <= 1'b0;
        coef_run  <= 1'b0;
        coef_ch   <= 2'd0;
        coef_bit  <= 4'd0;
        coef_acc  <= 19'd0;
        coef_a    <= 19'd0;
        coef_b    <= 19'd0;
        coef_sum  <= 19'd0;
        k_r_q     <= 10'd256;
        k_g_q     <= 10'd256;
        k_b_q     <= 10'd256;
    end
    else begin
        coef_arm <= dis_eff_in_vsync && !vsync_d;
        if(!coef_run && coef_arm) begin
            coef_run  <= 1'b1;
            coef_ch   <= 2'd0;
            coef_bit  <= 4'd0;
            coef_acc  <= 19'd0;
            coef_a    <= {10'd0, contrast_q8};
            coef_b    <= {9'd0, gain_r};
        end
        else if(coef_run && (coef_bit == 4'd8)) begin
            coef_sum <= coef_acc + (coef_a[0] ? coef_b : 19'd0);
            if(coef_ch == 2'd0)
                k_r_q <= coef_part;
            else if(coef_ch == 2'd1)
                k_g_q <= coef_part;
            else
                k_b_q <= coef_part;
            if(coef_ch == 2'd2) begin
                coef_run <= 1'b0;
            end
            else begin
                coef_ch  <= coef_ch + 2'd1;
                coef_bit <= 4'd0;
                coef_acc <= 19'd0;
                coef_a   <= {10'd0, contrast_q8};
                coef_b   <= (coef_ch == 2'd0) ? {9'd0, gain_g} : {9'd0, gain_b};
            end
        end
        else if(coef_run) begin
            if(coef_a[0])
                coef_acc <= coef_acc + coef_b;
            coef_a   <= coef_a >> 1;
            coef_b   <= coef_b << 1;
            coef_bit <= coef_bit + 4'd1;
        end
    end
end

wire signed     [7:0]           delta_r                     ;
wire signed     [7:0]           delta_g                     ;
wire signed     [7:0]           delta_b                     ;
reg  signed     [7:0]           delta_r_q                   ;
reg  signed     [7:0]           delta_g_q                   ;
reg  signed     [7:0]           delta_b_q                   ;
wire signed     [18:0]          prod_r_c                    ;
wire signed     [18:0]          prod_g_c                    ;
wire signed     [18:0]          prod_b_c                    ;
reg  signed     [17:0]          prod_r                      ;
reg  signed     [17:0]          prod_g                      ;
reg  signed     [17:0]          prod_b                      ;

assign delta_r = dis_eff_in_rgb[23:16] - 8'd128;
assign delta_g = dis_eff_in_rgb[15:8]  - 8'd128;
assign delta_b = dis_eff_in_rgb[7:0]   - 8'd128;

dsp_mul_s11x8 U_MUL_PIX_R(
    .CLK                        (clk                        ),
    .A                          ({1'b0, k_r_q}              ),
    .B                          (delta_r_q                  ),
    .P                          (prod_r_c                   )
);

dsp_mul_s11x8 U_MUL_PIX_G(
    .CLK                        (clk                        ),
    .A                          ({1'b0, k_g_q}              ),
    .B                          (delta_g_q                  ),
    .P                          (prod_g_c                   )
);

dsp_mul_s11x8 U_MUL_PIX_B(
    .CLK                        (clk                        ),
    .A                          ({1'b0, k_b_q}              ),
    .B                          (delta_b_q                  ),
    .P                          (prod_b_c                   )
);

always@(posedge clk) begin
    if(reset) begin
        prod_r     <= 18'sd0;
        prod_g     <= 18'sd0;
        prod_b     <= 18'sd0;
        delta_r_q  <= 8'sd0;
        delta_g_q  <= 8'sd0;
        delta_b_q  <= 8'sd0;
    end
    else begin
        delta_r_q  <= delta_r;
        delta_g_q  <= delta_g;
        delta_b_q  <= delta_b;
        prod_r     <= prod_r_c[17:0];
        prod_g     <= prod_g_c[17:0];
        prod_b     <= prod_b_c[17:0];
    end
end

wire signed     [17:0]          sh_r                        ;
wire signed     [17:0]          sh_g                        ;
wire signed     [17:0]          sh_b                        ;
wire signed     [17:0]          lumi_ext                    ;
wire signed     [17:0]          sum_r                       ;
wire signed     [17:0]          sum_g                       ;
wire signed     [17:0]          sum_b                       ;

assign sh_r     = prod_r >>> 8;
assign sh_g     = prod_g >>> 8;
assign sh_b     = prod_b >>> 8;
assign lumi_ext = {{9{lumi_s[8]}}, lumi_s};
assign sum_r    = sh_r + 18'sd128 + lumi_ext;
assign sum_g    = sh_g + 18'sd128 + lumi_ext;
assign sum_b    = sh_b + 18'sd128 + lumi_ext;

function automatic [7:0] sat8;
    input signed [17:0] v;
    begin
        if(v < 0)
            sat8 = 8'd0;
        else if(v > 18'sd255)
            sat8 = 8'd255;
        else
            sat8 = v[7:0];
    end
endfunction

always@(posedge clk) begin
    if(reset)
        proc_rgb_q <= 24'd0;
    else
        proc_rgb_q <= {sat8(sum_r), sat8(sum_g), sat8(sum_b)};
end

localparam                      PACK_W                      = 54;
wire            [PACK_W-1:0]   pack_in                     ;
reg             [PACK_W-1:0]   pack_dly [0:PIX_LAT-1]      ;
integer                         di                          ;
wire                            eff_dis_d                   ;
wire            [23:0]         eff_rgb_d                   ;
wire            [12:0]         eff_x_d                     ;
wire            [12:0]         eff_y_d                     ;
wire                            eff_in_pic                  ;
wire            [23:0]         eff_proc_rgb                ;

assign pack_in = {dis_eff_disable, dis_eff_in_rgb,
                  dis_eff_in_vsync, dis_eff_in_hsync, dis_eff_in_de,
                  dis_eff_in_xcnt, dis_eff_in_ycnt};

always@(posedge clk) begin
    if(reset) begin
        for(di = 0; di < PIX_LAT; di = di + 1)
            pack_dly[di] <= {PACK_W{1'b0}};
    end
    else begin
        pack_dly[0] <= pack_in;
        for(di = 1; di < PIX_LAT; di = di + 1)
            pack_dly[di] <= pack_dly[di-1];
    end
end

assign eff_dis_d        = pack_dly[PIX_LAT-1][53];
assign eff_rgb_d        = pack_dly[PIX_LAT-1][52:29];
assign dis_eff_out_vsync = pack_dly[PIX_LAT-1][28];
assign dis_eff_out_hsync = pack_dly[PIX_LAT-1][27];
assign dis_eff_out_de    = pack_dly[PIX_LAT-1][26];
assign dis_eff_out_xcnt  = pack_dly[PIX_LAT-1][25:13];
assign dis_eff_out_ycnt  = pack_dly[PIX_LAT-1][12:0];
assign eff_x_d          = dis_eff_out_xcnt;
assign eff_y_d          = dis_eff_out_ycnt;
assign eff_in_pic       = (eff_x_d < dis_eff_valid_width) &&
                          (eff_y_d >= 13'd1) &&
                          (eff_y_d <= dis_eff_valid_height);
assign eff_proc_rgb     = proc_rgb_q;
assign dis_eff_out_rgb  = eff_dis_d ? eff_rgb_d :
                          (eff_in_pic ? eff_proc_rgb : 24'h000000);

endmodule
