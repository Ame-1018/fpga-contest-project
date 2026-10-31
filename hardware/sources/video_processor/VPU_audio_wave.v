`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Create Date: 2026/10/20 17:40:00
// Design Name: 
// Module Name: VPU_audio_wave
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 左声道 16 位叠到 HDMI。只保留波形，不再画频谱。
//              128 根频率柱和 Goertzel 已去掉，省 DSP、状态 RAM 和系数 ROM。
//              窗口宽 640、高 128，左上角是 audio_wave_sx/sy，场同步才锁存。
//              只画 1280×640 画布内的部分，起点可以落在画布内任意点。
//              显示缓冲按场同步交换，扫描期间不再改正在画的那一页，避免斜切。
//              波形从左到右是时间，上下相对中线填充，样式同音频软件。
//              波形增益 192 用移位加法，不再占用 dsp_mul_s16x16。
//              采样 FIFO 32x16 放进块 RAM。显示 RAM 1024x8 乒乓。
//              颜色只保留两种：非 1 为青色，1 为彩虹。指定色不再进像素。
//              彩虹相位直接用窗口横坐标，不再做乘 205。
// 
// Dependencies: simple_dual_ram
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: 像素晚 3 拍。波形幅度在采样状态里寄存。
// 
//////////////////////////////////////////////////////////////////////////////////

module VPU_audio_wave(
    input   wire                clk                         ,
    input   wire                reset                       ,

    input   wire                vpu_audio_disable           ,
    input   wire    [1:0]       vpu_audio_mode              ,
    input   wire    [1:0]       vpu_audio_color_mode        ,
    input   wire    [23:0]      vpu_audio_color_data        ,
    input   wire    [12:0]      audio_wave_sx               ,
    input   wire    [12:0]      audio_wave_sy               ,
    input   wire                vpu_audio_valid             ,
    input   wire    [15:0]      vpu_audio_data              ,

    input   wire                audio_wave_in_vsync         ,
    input   wire                audio_wave_in_hsync         ,
    input   wire                audio_wave_in_de            ,
    input   wire    [12:0]      audio_wave_in_xcnt          ,
    input   wire    [12:0]      audio_wave_in_ycnt          ,
    input   wire    [23:0]      audio_wave_in_rgb           ,

    output  reg                 audio_wave_out_vsync        ,
    output  reg                 audio_wave_out_hsync        ,
    output  reg                 audio_wave_out_de           ,
    output  reg     [12:0]      audio_wave_out_xcnt         ,
    output  reg     [12:0]      audio_wave_out_ycnt         ,
    output  reg     [23:0]      audio_wave_out_rgb          
);

localparam                      S_CLRD                      = 5'd0;
localparam                      S_CLRS                      = 5'd1;
localparam                      S_IDLE                      = 5'd2;
localparam                      S_W0                        = 5'd3;
localparam                      S_W1                        = 5'd4;
localparam                      S_W2                        = 5'd5;
localparam                      S_WW                        = 5'd6;
localparam                      S_G0                        = 5'd7;
localparam                      S_G1                        = 5'd8;
localparam                      S_G2                        = 5'd9;
localparam                      S_G3                        = 5'd10;
localparam                      S_A0                        = 5'd11;
localparam                      S_A1                        = 5'd12;
localparam                      S_A2                        = 5'd13;
localparam                      S_A3                        = 5'd14;
localparam                      S_A4                        = 5'd15;
localparam                      S_B0                        = 5'd16;
localparam                      S_B1                        = 5'd17;

localparam      signed [15:0]  WAVE_GAIN                   = 16'sd192;
localparam      [23:0]          CYAN                        = 24'h00E5FF;
localparam                      FIFO_DEPTH                  = 32;

reg             [4:0]           state                       ;
reg             [9:0]           clr_addr                    ;
reg             [8:0]           wptr                        ;
reg             [8:0]           wave_origin                 ;
reg                             disp_bank                   ;
reg                             cap_dirty                   ;
reg             [9:0]           wr_count                    ;
reg             [7:0]           k                           ;
reg             [7:0]           blk_cnt                     ;
wire    signed  [15:0]          samp                        ;
reg     signed  [15:0]          xs                          ;
reg     signed  [15:0]          v1                          ;
reg     signed  [15:0]          v2                          ;
reg     signed  [15:0]          mul_a                       ;
reg     signed  [15:0]          mul_b                       ;
reg     signed  [31:0]          prod_r                      ;
reg     signed  [31:0]          re_r                        ;
reg             [15:0]          peak_r                      ;
reg             [3:0]           shift_r                     ;
reg             [7:0]           wy                          ;

reg             [4:0]           fifo_w                      ;
reg             [4:0]           fifo_r                      ;
reg             [5:0]           fifo_cnt                    ;

reg                             we_d                        ;
reg             [9:0]           ad_d                        ;
reg             [7:0]           din_d                       ;
reg                             we_s                        ;
reg             [6:0]           ad_s                        ;
reg             [6:0]           ab_s                        ;
reg             [31:0]          din_s                       ;

reg                             vsync_d                     ;
reg                             dis_l                       ;
reg             [1:0]           mode_l                      ;
reg             [1:0]           cmode_l                     ;
reg             [23:0]          cdata_l                     ;
reg             [12:0]          sx_l                        ;
reg             [12:0]          sy_l                        ;

reg                             s1_vs, s1_hs, s1_de, s1_in  ;
reg             [1:0]           s1_mode                     ;
reg             [1:0]           s1_cmode                    ;
reg             [23:0]          s1_cdata                    ;
reg             [12:0]          s1_x, s1_y, s1_bot          ;
reg             [9:0]           s1_lx                       ;
reg             [23:0]          s1_rgb                      ;
reg             [7:0]           s1_bar                      ;
reg             [2:0]           s1_slot                     ;
reg                             s2_vs, s2_hs, s2_de, s2_in  ;
reg             [1:0]           s2_mode                     ;
reg             [1:0]           s2_cmode                    ;
reg             [23:0]          s2_cdata                    ;
reg             [12:0]          s2_x, s2_y, s2_bot          ;
reg             [9:0]           s2_lx                       ;
reg             [23:0]          s2_rgb                      ;
reg             [7:0]           s2_bar                      ;
reg             [2:0]           s2_slot                     ;
reg             [7:0]           s2_mem                      ;
// 时序：75 MHz 彩虹从横坐标乘 205 再混合，13 级加法，slack -0.137ns。
// 相位和同步先打一拍，混合只用这一拍。
reg             [7:0]           hue_ph_q                    ;
reg                             stroke_q                    ;
reg                             filled_q                    ;
reg                             bar_on_q                    ;
reg                             s3_vs, s3_hs, s3_de, s3_in  ;
reg             [1:0]           s3_mode                     ;
reg             [1:0]           s3_cmode                    ;
reg             [23:0]          s3_cdata                    ;
reg             [23:0]          s3_rgb                      ;
reg             [12:0]          s3_x, s3_y                  ;

reg     signed  [15:0]          trom [0:383]                ;

wire            [31:0]          prod_c                      ;
wire            [7:0]           dout_d                      ;
wire            [31:0]          dout_s                      ;
wire                            pop                         ;
wire                            push                        ;
wire                            vsync_rise                  ;
wire            [12:0]          bot                         ;
wire            [12:0]          x_rel                       ;
wire                            in_x                        ;
wire                            in_y                        ;
wire                            draw_mode                   ;
wire                            disp_lock                   ;
wire            [9:0]           x10                         ;
wire            [17:0]          x_ext                       ;
wire            [17:0]          x205                        ;
wire            [7:0]           bar_idx                     ;
wire            [9:0]           bar5                        ;
wire            [9:0]           slot_full                   ;
wire            [8:0]           wave_col                    ;
wire            [9:0]           wave_sum                    ;
wire            [8:0]           wave_idx                    ;
wire            [9:0]           disp_addr                   ;
wire            [9:0]           cap_wave_base               ;
wire            [9:0]           cap_bar_base                ;
wire    signed  [15:0]          coeff_k                     ;
wire    signed  [15:0]          cos_k                       ;
wire    signed  [15:0]          sin_k                       ;
wire    signed  [31:0]          y_sh                        ;
wire    signed  [31:0]          term                        ;
wire    signed  [31:0]          acc32                       ;
wire    signed  [15:0]          vnew                        ;
wire    signed  [31:0]          im_s                        ;
wire    signed  [31:0]          re_abs                      ;
wire    signed  [31:0]          im_abs                      ;
wire            [31:0]          mag_wide                    ;
wire            [15:0]          mag_sat                     ;
wire            [15:0]          peak_next                   ;
wire            [15:0]          mag_sh                      ;
wire            [7:0]           h_raw                       ;
wire            [12:0]          center                      ;
wire            [12:0]          sample_y                    ;
wire    signed  [13:0]          y_delta                     ;
wire                            stroke                      ;
wire            [12:0]          y_lo                        ;
wire            [12:0]          y_hi                        ;
wire                            filled                      ;
wire            [12:0]          bar_top                     ;
wire                            bar_on                      ;
wire            [7:0]           hue_ph                      ;
wire            [23:0]          fg_rgb                      ;
wire            [23:0]          rgb_mix                     ;
wire                            audio_busy                  ;
wire                            snap_ready                  ;

assign bot        = sy_l + 13'd127;
assign x_rel      = audio_wave_in_xcnt - sx_l;
assign in_x       = (audio_wave_in_xcnt >= sx_l) && (x_rel < 13'd640) &&
                    (audio_wave_in_xcnt < 13'd1280);
assign in_y       = (audio_wave_in_ycnt >= sy_l) &&
                    ((audio_wave_in_ycnt - sy_l) <= 13'd127) &&
                    (audio_wave_in_ycnt < 13'd640);
assign draw_mode  = 1'b1;
assign disp_lock  = draw_mode && !dis_l && audio_wave_in_de && in_x && in_y;
assign x10        = x_rel[9:0];
assign wave_col   = {1'b0, x10[9:1]};
assign wave_sum   = {1'b0, wave_origin} + {1'b0, wave_col};
assign wave_idx   = (wave_sum >= 10'd320) ? (wave_sum - 10'd320) : wave_sum[8:0];
assign disp_addr  = (disp_bank ? 10'd320 : 10'd0) + {1'b0, wave_idx};
assign cap_wave_base = disp_bank ? 10'd0   : 10'd320;
assign vsync_rise = audio_wave_in_vsync && !vsync_d;
assign pop        = (state == S_IDLE) && (fifo_cnt != 6'd0);
assign push       = vpu_audio_valid && ((fifo_cnt < FIFO_DEPTH) || pop);
assign audio_busy = (state != S_IDLE) || (fifo_cnt != 6'd0);
assign snap_ready = (state == S_IDLE) && (fifo_cnt == 6'd0);

assign y_sh       = prod_r >>> 15;

simple_dual_ram #(
    .RAM_WIDTH                  (8                          ),
    .RAM_DEPTH                  (1024                       ),
    .PERFORMENCE                ("LOW"                      )
)U_DISP(
    .clka                       (clk                        ),
    .wea                        (we_d                       ),
    .dina                       (din_d                      ),
    .addra                      (ad_d                       ),
    .addrb                      (disp_lock ? disp_addr : 10'd0),
    .doutb                      (dout_d                     )
);

always@(posedge clk) begin
    if(reset) begin
        vsync_d <= 1'b0;
        dis_l   <= 1'b0;
        mode_l  <= 2'd0;
        cmode_l <= 2'd0;
        cdata_l <= CYAN;
        sx_l    <= 13'd0;
        sy_l    <= 13'd353;
    end
    else begin
        vsync_d <= audio_wave_in_vsync;
        if(vsync_rise) begin
            dis_l   <= vpu_audio_disable;
            mode_l  <= vpu_audio_mode;
            cmode_l <= vpu_audio_color_mode;
            cdata_l <= vpu_audio_color_data;
            sx_l    <= audio_wave_sx;
            sy_l    <= audio_wave_sy;
        end
    end
end

always@(posedge clk) begin
    if(reset) begin
        state       <= S_CLRD;
        clr_addr    <= 10'd0;
        wptr        <= 9'd0;
        wave_origin <= 9'd0;
        disp_bank   <= 1'b0;
        cap_dirty   <= 1'b0;
        wr_count    <= 10'd0;
        k           <= 8'd0;
        blk_cnt     <= 8'd0;
        xs          <= 16'sd0;
        v1          <= 16'sd0;
        v2          <= 16'sd0;
        mul_a       <= 16'sd0;
        mul_b       <= 16'sd0;
        prod_r      <= 32'sd0;
        re_r        <= 32'sd0;
        peak_r      <= 16'd0;
        shift_r     <= 4'd0;
        wy          <= 8'd64;
        we_d        <= 1'b0;
        ad_d        <= 10'd0;
        din_d       <= 8'd0;
        we_s        <= 1'b0;
        ad_s        <= 7'd0;
        ab_s        <= 7'd0;
        din_s       <= 32'd0;
        fifo_w      <= 5'd0;
        fifo_r      <= 5'd0;
        fifo_cnt    <= 6'd0;
    end
    else begin
        we_d <= 1'b0;
        we_s <= 1'b0;
        case(state)
            S_CLRD: begin
                we_d  <= 1'b1;
                ad_d  <= clr_addr;
                din_d <= (clr_addr < 10'd640) ? 8'd64 : 8'd0;
                if(clr_addr == 10'd1023) begin
                    clr_addr <= 10'd0;
                    state    <= S_IDLE;
                end
                else
                    clr_addr <= clr_addr + 10'd1;
            end
            S_IDLE: begin
            end
            S_W0: begin
                mul_a <= samp;
                mul_b <= WAVE_GAIN;
                xs    <= samp >>> 8;
                state <= S_W1;
            end
            S_W1: begin
                prod_r <= ({{16{samp[15]}}, samp} << 7) + ({{16{samp[15]}}, samp} << 6);
                fifo_r <= fifo_r + 5'd1;
                state  <= S_W2;
            end
            S_W2: begin
                if(y_sh > 32'sd63)
                    wy <= 8'd127;
                else if(y_sh < -32'sd63)
                    wy <= 8'd1;
                else
                    wy <= y_sh[7:0] + 8'd64;
                state <= S_WW;
            end
            S_WW: begin
                we_d      <= 1'b1;
                ad_d      <= cap_wave_base + {1'b0, wptr};
                din_d     <= wy;
                wptr      <= (wptr == 9'd319) ? 9'd0 : (wptr + 9'd1);
                if(wr_count < 10'd320)
                    wr_count <= wr_count + 10'd1;
                cap_dirty <= 1'b1;
                state     <= S_IDLE;
            end
            default: begin
                state <= S_IDLE;
            end
        endcase

        if(vsync_rise && cap_dirty) begin
            disp_bank   <= ~disp_bank;
            wave_origin <= (wr_count >= 10'd320) ? wptr : 9'd0;
            wptr        <= 9'd0;
            wr_count    <= 10'd0;
            cap_dirty   <= 1'b0;
        end

        if(push && !pop)
            fifo_cnt <= fifo_cnt + 6'd1;
        else if(!push && pop)
            fifo_cnt <= fifo_cnt - 6'd1;
        if(push)
            fifo_w <= fifo_w + 5'd1;
        if(pop)
            state <= S_W0;
    end
end

simple_dual_ram #(
    .RAM_WIDTH                  (16                         ),
    .RAM_DEPTH                  (32                         ),
    .PERFORMENCE                ("LOW"                      )
)U_FIFO(
    .clka                       (clk                        ),
    .wea                        (push && !reset             ),
    .dina                       (vpu_audio_data             ),
    .addra                      (fifo_w                     ),
    .addrb                      (fifo_r                     ),
    .doutb                      (samp                       )
);

always@(posedge clk) begin
    if(reset) begin
        s1_vs <= 1'b0; s1_hs <= 1'b0; s1_de <= 1'b0; s1_in <= 1'b0;
        s1_mode <= 2'd0; s1_cmode <= 2'd0; s1_cdata <= CYAN;
        s1_x <= 13'd0; s1_y <= 13'd0; s1_bot <= 13'd0; s1_lx <= 10'd0;
        s1_rgb <= 24'd0; s1_bar <= 8'd0; s1_slot <= 3'd0;
        s2_vs <= 1'b0; s2_hs <= 1'b0; s2_de <= 1'b0; s2_in <= 1'b0;
        s2_mode <= 2'd0; s2_cmode <= 2'd0; s2_cdata <= CYAN;
        s2_x <= 13'd0; s2_y <= 13'd0; s2_bot <= 13'd0; s2_lx <= 10'd0;
        s2_rgb <= 24'd0; s2_bar <= 8'd0; s2_slot <= 3'd0; s2_mem <= 8'd64;
    end
    else begin
        s1_vs   <= audio_wave_in_vsync;
        s1_hs   <= audio_wave_in_hsync;
        s1_de   <= audio_wave_in_de;
        s1_in   <= disp_lock;
        s1_mode  <= mode_l;
        s1_cmode <= cmode_l;
        s1_cdata <= cdata_l;
        s1_x    <= audio_wave_in_xcnt;
        s1_y    <= audio_wave_in_ycnt;
        s1_lx   <= x10;
        s1_bot  <= bot;
        s1_rgb  <= audio_wave_in_rgb;
        s2_vs   <= s1_vs;
        s2_hs   <= s1_hs;
        s2_de   <= s1_de;
        s2_in   <= s1_in;
        s2_mode  <= s1_mode;
        s2_cmode <= s1_cmode;
        s2_cdata <= s1_cdata;
        s2_x    <= s1_x;
        s2_y    <= s1_y;
        s2_lx   <= s1_lx;
        s2_bot  <= s1_bot;
        s2_rgb  <= s1_rgb;
        s2_bar  <= s1_bar;
        s2_slot <= s1_slot;
        s2_mem  <= dout_d;
    end
end

assign center   = s2_bot - 13'd64;
assign sample_y = s2_bot - {5'd0, s2_mem};
assign y_delta  = $signed({1'b0, s2_y}) - $signed({1'b0, sample_y});
assign stroke   = (y_delta <= 14'sd1) && (y_delta >= -14'sd1);
assign y_lo     = (sample_y < center) ? sample_y : center;
assign y_hi     = (sample_y > center) ? sample_y : center;
assign filled   = (s2_y >= y_lo) && (s2_y <= y_hi);
assign bar_top  = s2_bot - {5'd0, s2_mem} + 13'd1;
assign bar_on   = (s2_mem != 8'd0) && (s2_slot < 3'd4) &&
                  (s2_y >= bar_top) && (s2_y <= s2_bot);

function [7:0] hue_tri;
    input [7:0] phase;
    reg   [7:0] fold;
    begin
        if(phase < 8'd128)
            hue_tri = {phase[6:0], 1'b0};
        else begin
            fold    = 8'd255 - phase;
            hue_tri = {fold[6:0], 1'b0};
        end
    end
endfunction

function [7:0] mix25;
    input [7:0] bg;
    input [7:0] fg;
    reg   [9:0] sum;
    begin
        sum   = {2'd0, bg} + {2'd0, bg} + {2'd0, bg} + {2'd0, fg};
        mix25 = sum[9:2];
    end
endfunction

function [7:0] mix50;
    input [7:0] bg;
    input [7:0] fg;
    reg   [8:0] sum;
    begin
        sum   = {1'b0, bg} + {1'b0, fg};
        mix50 = sum[8:1];
    end
endfunction

assign hue_ph  = s2_lx[8:1];
assign fg_rgb  = (s3_cmode == 2'd1) ? {hue_tri(hue_ph_q),
                                       hue_tri(hue_ph_q + 8'd85),
                                       hue_tri(hue_ph_q + 8'd170)} :
                                      CYAN;

assign rgb_mix =
    (!s3_in) ? s3_rgb :
    (stroke_q ? fg_rgb :
     filled_q ? {mix25(s3_rgb[23:16], fg_rgb[23:16]),
                 mix25(s3_rgb[15:8],  fg_rgb[15:8]),
                 mix25(s3_rgb[7:0],   fg_rgb[7:0])} :
                s3_rgb);

always@(posedge clk) begin
    if(reset) begin
        audio_wave_out_vsync <= 1'b0;
        audio_wave_out_hsync <= 1'b0;
        audio_wave_out_de    <= 1'b0;
        audio_wave_out_xcnt  <= 13'd0;
        audio_wave_out_ycnt  <= 13'd0;
        audio_wave_out_rgb   <= 24'd0;
        hue_ph_q  <= 8'd0;
        stroke_q  <= 1'b0;
        filled_q  <= 1'b0;
        bar_on_q  <= 1'b0;
        s3_vs <= 1'b0; s3_hs <= 1'b0; s3_de <= 1'b0; s3_in <= 1'b0;
        s3_mode <= 2'd0; s3_cmode <= 2'd0;
        s3_cdata <= 24'd0; s3_rgb <= 24'd0;
        s3_x <= 13'd0; s3_y <= 13'd0;
    end
    else begin
        hue_ph_q <= hue_ph;
        stroke_q <= stroke;
        filled_q <= filled;
        bar_on_q <= bar_on;
        s3_vs    <= s2_vs;
        s3_hs    <= s2_hs;
        s3_de    <= s2_de;
        s3_in    <= s2_in;
        s3_mode  <= s2_mode;
        s3_cmode <= s2_cmode;
        s3_cdata <= s2_cdata;
        s3_rgb   <= s2_rgb;
        s3_x     <= s2_x;
        s3_y     <= s2_y;
        audio_wave_out_vsync <= s3_vs;
        audio_wave_out_hsync <= s3_hs;
        audio_wave_out_de    <= s3_de;
        audio_wave_out_xcnt  <= s3_x;
        audio_wave_out_ycnt  <= s3_y;
        audio_wave_out_rgb   <= rgb_mix;
    end
end

endmodule
