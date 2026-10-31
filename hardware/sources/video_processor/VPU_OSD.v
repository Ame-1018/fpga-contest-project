`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Module Name: VPU_OSD
// Description: 在有效画面上叠 128x128 安路 logo 和一行字幕。
//              logo 用 rom_anlogic_logo_128x128，ERAM32K，4096x8。
//              从左到右、从上到下，每字节 4 个像素，左边的像素在 [7:6]。
//              一行 32 字节。地址 {行[6:0], 列[6:2]}。边缘已收成红或藏青。
//              字幕用 osd_txt_ram，ERAM32K，2048x32。高 32、宽 2048。
//              每个字 32x32。地址 {行[4:0], 列[10:5]}，bit31 是左像素。
//              显示窗从 osd_txt_sx/sy 起，宽 osd_txt_x_area，高 32。
//              点阵按已用字宽循环左移。速度 0 暂停，1～3 为每场移动的像素数。
//              字幕颜色只保留两种：0 及非 1 为白，1 为彩虹。指定色不再进像素。
//              osd_txt_disable 为 1 时不画字。osd_txtram_* 在此期间改点阵。
//              只关字幕时循环宽度保持不变。写过点阵后，在关闭落下时
//              才换成这次量到的宽度，避免窗口里反复画出第一个字。
//              32K ERAM 在 NOREG 下读延迟是 1 拍。写口、读地址、读数据
//              在片外再各打 2 拍。像素与这 1 拍对齐，输出比输入晚 6 拍。
//              字幕按最右边有墨迹的 32 像素格循环，不把后面的空白 RAM 滚完。
//              右上角不再叠参数。亮度、风格和音频改由拨码菜单显示。
//
// Dependencies: rom_anlogic_logo_128x128, osd_txt_ram
//              仿真定义 OSD_SIM，用同延迟的行为模型并读 mem。
// 
// Additional Comments: 2'b00 透出底图。2'b01 红 24'hED1C24。2'b10 藏青 24'h1C2D4E。
// 
//////////////////////////////////////////////////////////////////////////////////

module VPU_OSD #(
    parameter                   LOGO_INIT_FILE              = "../sources/osd/osd_logo_128_init.mem",
    parameter                   TXT_INIT_FILE               = "../sources/osd/osd_txt_init.mem"
)(
    input   wire                clk                         ,
    input   wire                reset                       ,

    input   wire    [12:0]      osd_valid_width             ,
    input   wire    [12:0]      osd_valid_height            ,
    input   wire                osd_disable                 ,
    
    input   wire    [12:0]      osd_logo_sx                 ,
    input   wire    [12:0]      osd_logo_sy                 ,

    input   wire    [12:0]      osd_txt_sx                  ,
    input   wire    [12:0]      osd_txt_sy                  ,
    input   wire    [12:0]      osd_txt_x_area              ,
    input   wire    [1:0]       osd_txt_speed               ,
    input   wire    [1:0]       osd_color_mode              ,
    input   wire    [23:0]      osd_color_set               ,

    input   wire                osd_txt_disable             ,
    input   wire                osd_txtram_dv               ,
    input   wire    [31:0]      osd_txtram_data             ,
    input   wire    [10:0]      osd_txtram_addr             ,

    input   wire                osd_in_vsync                ,
    input   wire                osd_in_hsync                ,
    input   wire                osd_in_de                   ,
    input   wire    [12:0]      osd_in_xcnt                 ,
    input   wire    [12:0]      osd_in_ycnt                 ,
    input   wire    [23:0]      osd_in_rgb                  ,

    output  reg                 osd_out_vsync               ,
    output  reg                 osd_out_hsync               ,
    output  reg                 osd_out_de                  ,
    output  reg     [12:0]      osd_out_xcnt                ,
    output  reg     [12:0]      osd_out_ycnt                ,
    output  reg     [23:0]      osd_out_rgb                 
);

localparam  [23:0]              COLOR_RED                   = 24'hED1C24;
localparam  [23:0]              COLOR_NAVY                  = 24'h1C2D4E;
localparam                      LOGO_SIDE                   = 128;
localparam                      TXT_H                       = 32;
localparam      [11:0]          TXT_SPAN_INIT               = 12'd832;
localparam                      PIPE                        = 5;

reg                             vsync_d                     ;
reg                             txt_dis_d                   ;
reg                             txt_dirty                   ;
reg             [11:0]          span_acc                    ;
reg             [11:0]          txt_span                    ;
reg             [11:0]          scroll_use                  ;
reg             [11:0]          scroll_next                 ;
reg             [11:0]          bmp_hold                    ;
reg             [7:0]           hue_use                     ;
reg             [7:0]           hue_next                    ;

wire                            in_pic                      ;
wire                            in_logo                     ;
wire                            in_txt                      ;
wire            [12:0]          logo_x_rel                  ;
wire            [12:0]          logo_y_rel                  ;
wire            [12:0]          txt_x_rel                   ;
wire            [12:0]          txt_y_rel                   ;
wire            [12:0]          txt_x_end                   ;
wire            [11:0]          bmp_inc                     ;
wire            [11:0]          bmp_pix                     ;
wire            [10:0]          bmp_x                       ;
wire            [11:0]          scrolled                    ;
wire            [11:0]          word_end                    ;
wire            [10:0]          txt_rd_addr                 ;
wire            [11:0]          logo_rd_addr                ;
wire            [1:0]           logo_pix                    ;
wire                            txt_bit                     ;
wire            [23:0]          txt_rgb                     ;
wire            [23:0]          logo_rgb                    ;
reg             [23:0]          rgb_calc                    ;

reg                             txt_we1                     ;
reg                             txt_we2                     ;
reg             [10:0]          txt_wa1                     ;
reg             [10:0]          txt_wa2                     ;
reg             [31:0]          txt_d1                      ;
reg             [31:0]          txt_d2                      ;
reg             [11:0]          logo_a1                     ;
reg             [11:0]          logo_a2                     ;
reg             [10:0]          txt_a1                      ;
reg             [10:0]          txt_a2                      ;
reg             [7:0]           logo_q1                     ;
reg             [7:0]           logo_q2                     ;
reg             [31:0]          txt_q1                      ;
reg             [31:0]          txt_q2                      ;

reg             [PIPE-1:0]      p_vs                        ;
reg             [PIPE-1:0]      p_hs                        ;
reg             [PIPE-1:0]      p_de                        ;
reg             [PIPE-1:0]      p_dis                       ;
reg             [PIPE-1:0]      p_pic                       ;
reg             [PIPE-1:0]      p_logo                      ;
reg             [PIPE-1:0]      p_txt                       ;
reg             [PIPE-1:0]      p_tdis                      ;
reg             [12:0]          p_x             [0:PIPE-1]  ;
reg             [12:0]          p_y             [0:PIPE-1]  ;
reg             [23:0]          p_rgb           [0:PIPE-1]  ;
reg             [6:0]           p_lx            [0:PIPE-1]  ;
reg             [10:0]          p_bx            [0:PIPE-1]  ;
reg             [1:0]           p_mode          [0:PIPE-1]  ;
reg             [7:0]           p_phase         [0:PIPE-1]  ;
integer                         pi                          ;

`ifdef OSD_SIM
reg             [7:0]           logo_raw                    ;
reg             [31:0]          txt_raw                     ;
`else
wire            [7:0]           logo_raw                    ;
wire            [31:0]          txt_raw                     ;
`endif

assign in_pic = (osd_in_xcnt < osd_valid_width) &&
                (osd_in_ycnt >= 13'd1) &&
                (osd_in_ycnt <= osd_valid_height);
assign logo_x_rel = osd_in_xcnt - osd_logo_sx;
assign logo_y_rel = osd_in_ycnt - osd_logo_sy;
assign in_logo = in_pic &&
                 (osd_in_xcnt >= osd_logo_sx) &&
                 (logo_x_rel < LOGO_SIDE) &&
                 (osd_in_ycnt >= osd_logo_sy) &&
                 (logo_y_rel < LOGO_SIDE);
assign txt_x_end = osd_txt_sx + osd_txt_x_area;
assign txt_x_rel = osd_in_xcnt - osd_txt_sx;
assign txt_y_rel = osd_in_ycnt - osd_txt_sy;
assign in_txt = in_pic &&
                (osd_in_xcnt >= osd_txt_sx) &&
                (osd_in_xcnt < txt_x_end) &&
                (osd_in_ycnt >= osd_txt_sy) &&
                (txt_y_rel < TXT_H);
assign bmp_inc = bmp_hold + 12'd1;
assign bmp_pix = (osd_in_xcnt == osd_txt_sx) ? scroll_use :
                 ((bmp_inc >= txt_span) ? 12'd0 : bmp_inc);
assign bmp_x = bmp_pix[10:0];
assign scrolled = scroll_next + {10'd0, osd_txt_speed};
assign word_end = {1'b0, txt_wa1[5:0], 5'd0} + 12'd32;
assign txt_rd_addr = in_txt ? {txt_y_rel[4:0], bmp_x[10:5]} : 11'd0;
assign logo_rd_addr = in_logo ? {logo_y_rel[6:0], logo_x_rel[6:2]} : 12'd0;

`ifdef OSD_SIM
reg             [7:0]           lmem            [0:4095]    ;
reg             [31:0]          tmem            [0:2047]    ;
initial begin
    $readmemh(LOGO_INIT_FILE, lmem);
    $readmemh(TXT_INIT_FILE, tmem);
end
always @(posedge clk) begin
    if(txt_we2)
        tmem[txt_wa2] <= txt_d2;
    logo_raw <= lmem[logo_a2];
    txt_raw <= tmem[txt_a2];
end
`else
rom_anlogic_logo_128x128 u_logo (
    .doa                        (logo_raw                   ),
    .addra                      (logo_a2                    ),
    .clka                       (clk                        )
);

osd_txt_ram u_txt (
    .dia                        (txt_d2                     ),
    .addra                      (txt_wa2                    ),
    .clka                       (clk                        ),
    .wea                        (txt_we2                    ),
    .dob                        (txt_raw                    ),
    .addrb                      (txt_a2                     ),
    .clkb                       (clk                        )
);

`endif

function [7:0] hue_tri;
    input [7:0] phase;
    reg   [7:0] fold;
    begin
        if(phase < 8'd128)
            hue_tri = {phase[6:0], 1'b0};
        else begin
            fold = 8'd255 - phase;
            hue_tri = {fold[6:0], 1'b0};
        end
    end
endfunction

function [1:0] take2;
    input [7:0] word;
    input [1:0] sel;
    begin
        case(sel)
            2'd0:       take2 = word[7:6];
            2'd1:       take2 = word[5:4];
            2'd2:       take2 = word[3:2];
            default:    take2 = word[1:0];
        endcase
    end
endfunction

assign logo_pix = take2(logo_q2, p_lx[PIPE-1][1:0]);
assign txt_bit = txt_q2[5'd31 - p_bx[PIPE-1][4:0]];
assign txt_rgb = (p_mode[PIPE-1] == 2'd1) ? {hue_tri(p_phase[PIPE-1]),
                                     hue_tri(p_phase[PIPE-1] + 8'd85),
                                     hue_tri(p_phase[PIPE-1] + 8'd170)} :
                 24'hFFFFFF;
assign logo_rgb = (logo_pix == 2'b10) ? COLOR_NAVY : COLOR_RED;

always@(*) begin
    if(p_dis[PIPE-1])
        rgb_calc = p_rgb[PIPE-1];
    else if(!p_pic[PIPE-1])
        rgb_calc = 24'h000000;
    else if(p_txt[PIPE-1] && !p_tdis[PIPE-1] && txt_bit)
        rgb_calc = txt_rgb;
    else if(p_logo[PIPE-1] && ((logo_pix == 2'b01) || (logo_pix == 2'b10)))
        rgb_calc = logo_rgb;
    else
        rgb_calc = p_rgb[PIPE-1];
end

always@(posedge clk) begin
    if(reset) begin
        vsync_d     <= 1'b0;
        txt_dis_d   <= 1'b0;
        txt_dirty   <= 1'b0;
        span_acc    <= 12'd32;
        txt_span    <= TXT_SPAN_INIT;
        scroll_use  <= 12'd0;
        scroll_next <= 12'd0;
        bmp_hold    <= 12'd0;
        hue_use     <= 8'd0;
        hue_next    <= 8'd0;
    end
    else begin
        vsync_d <= osd_in_vsync;
        txt_dis_d <= osd_txt_disable;
        bmp_hold <= bmp_pix;
        if(osd_txt_disable && !txt_dis_d) begin
            txt_dirty <= 1'b0;
            span_acc  <= 12'd32;
        end
        else if(!osd_txt_disable && txt_dis_d) begin
            if(txt_dirty || txt_we1) begin
                if(txt_we1 && (txt_d1 != 32'd0) && (word_end > span_acc))
                    txt_span <= word_end;
                else
                    txt_span <= span_acc;
                scroll_use  <= 12'd0;
                scroll_next <= 12'd0;
                txt_dirty   <= 1'b0;
            end
        end
        else if(txt_we1 && osd_txt_disable) begin
            txt_dirty <= 1'b1;
            if((txt_d1 != 32'd0) && (word_end > span_acc))
                span_acc <= word_end;
        end
        if(osd_in_vsync && !vsync_d) begin
            scroll_use  <= scroll_next;
            hue_use     <= hue_next;
            hue_next    <= hue_next + 8'd3;
            if((osd_txt_speed != 2'd0) && !osd_txt_disable) begin
                if(scrolled >= txt_span)
                    scroll_next <= scrolled - txt_span;
                else
                    scroll_next <= scrolled;
            end
        end
    end
end

always@(posedge clk) begin
    if(reset) begin
        txt_we1 <= 1'b0;
        txt_we2 <= 1'b0;
        txt_wa1 <= 11'd0;
        txt_wa2 <= 11'd0;
        txt_d1  <= 32'd0;
        txt_d2  <= 32'd0;
        logo_a1 <= 12'd0;
        logo_a2 <= 12'd0;
        txt_a1  <= 11'd0;
        txt_a2  <= 11'd0;
        logo_q1 <= 8'd0;
        logo_q2 <= 8'd0;
        txt_q1  <= 32'd0;
        txt_q2  <= 32'd0;
        p_vs    <= {PIPE{1'b0}};
        p_hs    <= {PIPE{1'b0}};
        p_de    <= {PIPE{1'b0}};
        p_dis   <= {PIPE{1'b0}};
        p_pic   <= {PIPE{1'b0}};
        p_logo  <= {PIPE{1'b0}};
        p_txt   <= {PIPE{1'b0}};
        p_tdis  <= {PIPE{1'b0}};
        for(pi = 0; pi < PIPE; pi = pi + 1) begin
            p_x[pi]     <= 13'd0;
            p_y[pi]     <= 13'd0;
            p_rgb[pi]   <= 24'd0;
            p_lx[pi]    <= 7'd0;
            p_bx[pi]    <= 11'd0;
            p_mode[pi]  <= 2'd0;
            p_phase[pi] <= 8'd0;
        end
    end
    else begin
        txt_we1 <= osd_txtram_dv;
        txt_wa1 <= osd_txtram_addr;
        txt_d1  <= osd_txtram_data;
        txt_we2 <= txt_we1;
        txt_wa2 <= txt_wa1;
        txt_d2  <= txt_d1;
        logo_a1 <= logo_rd_addr;
        logo_a2 <= logo_a1;
        txt_a1  <= txt_rd_addr;
        txt_a2  <= txt_a1;
        logo_q1 <= logo_raw;
        logo_q2 <= logo_q1;
        txt_q1  <= txt_raw;
        txt_q2  <= txt_q1;
        p_vs    <= {p_vs[PIPE-2:0], osd_in_vsync};
        p_hs    <= {p_hs[PIPE-2:0], osd_in_hsync};
        p_de    <= {p_de[PIPE-2:0], osd_in_de};
        p_dis   <= {p_dis[PIPE-2:0], osd_disable};
        p_pic   <= {p_pic[PIPE-2:0], in_pic};
        p_logo  <= {p_logo[PIPE-2:0], in_logo};
        p_txt   <= {p_txt[PIPE-2:0], in_txt};
        p_tdis  <= {p_tdis[PIPE-2:0], osd_txt_disable};
        p_x[0]     <= osd_in_xcnt;
        p_y[0]     <= osd_in_ycnt;
        p_rgb[0]   <= osd_in_rgb;
        p_lx[0]    <= logo_x_rel[6:0];
        p_bx[0]    <= bmp_x;
        p_mode[0]  <= osd_color_mode;
        p_phase[0] <= hue_use + bmp_x[7:0];
        for(pi = 1; pi < PIPE; pi = pi + 1) begin
            p_x[pi]     <= p_x[pi-1];
            p_y[pi]     <= p_y[pi-1];
            p_rgb[pi]   <= p_rgb[pi-1];
            p_lx[pi]    <= p_lx[pi-1];
            p_bx[pi]    <= p_bx[pi-1];
            p_mode[pi]  <= p_mode[pi-1];
            p_phase[pi] <= p_phase[pi-1];
        end
    end
end

always@(posedge clk) begin
    if(reset) begin
        osd_out_vsync <= 1'b0;
        osd_out_hsync <= 1'b0;
        osd_out_de    <= 1'b0;
        osd_out_xcnt  <= 13'd0;
        osd_out_ycnt  <= 13'd0;
        osd_out_rgb   <= 24'd0;
    end
    else begin
        osd_out_vsync <= p_vs[PIPE-1];
        osd_out_hsync <= p_hs[PIPE-1];
        osd_out_de    <= p_de[PIPE-1];
        osd_out_xcnt  <= p_x[PIPE-1];
        osd_out_ycnt  <= p_y[PIPE-1];
        osd_out_rgb   <= rgb_calc;
    end
end

endmodule
