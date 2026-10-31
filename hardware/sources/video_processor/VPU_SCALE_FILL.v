`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: VPU_SCALE_FILL
// Description: 用 HDMI 的 VS/HS/DE/X/Y 做最近邻缩放，只替换 RGB。
//              小数不低于 0.5 取下一采样点，否则取当前点。行缓存和拍数仍按双线性留下。
//              目标矩形在左上角，矩形外为黑，DE 宽度保持不变。
//              读出的源行先送进转场。系数随像素变化时，当前图整行进暂存，
//              下一张到达后再混合，混合结果写入四块行缓存。
//              输出相对 HDMI 输入固定 SCALE_LAT 拍，与转场开或关无关。
//              缩放关闭时目标宽高改成源宽高，仍然走这条行读。
//////////////////////////////////////////////////////////////////////////////////

module VPU_SCALE_FILL #(
    parameter                   SCALE_LAT                   = 8
)(
    input   wire                clk                         ,
    input   wire                reset                       ,

    input   wire                enable                      ,
    input   wire    [12:0]      src_w                       ,
    input   wire    [12:0]      src_h                       ,
    input   wire    [12:0]      dst_w                       ,
    input   wire    [12:0]      dst_h                       ,

    input   wire                in_vsync                    ,
    input   wire                in_hsync                    ,
    input   wire                in_de                       ,
    input   wire    [12:0]      in_xcnt                     ,
    input   wire    [12:0]      in_ycnt                     ,

    input   wire                cut_disable                 ,
    input   wire    [2:0]       cut_mode                    ,
    input   wire    [1:0]       cut_speed                   ,
    input   wire                cut_pchange                 ,
    output  wire                cut_active                  ,
    output  wire                cut_done                    ,

    output  reg                 run                         ,
    output  reg                 flush                       ,

    output  reg                 line_req                    ,
    output  reg     [12:0]      line_y                      ,
    output  reg     [1:0]       line_bank                   ,
    output  reg                 line_pic                    ,
    input   wire                line_ack                    ,

    output  wire                pix_re                      ,
    input   wire    [23:0]      pix_data                    ,
    input   wire                pix_empty                   ,
    input   wire                pix_valid                   ,

    output  wire                out_vsync                   ,
    output  wire                out_hsync                   ,
    output  wire                out_de                      ,
    output  wire    [12:0]      out_xcnt                    ,
    output  wire    [12:0]      out_ycnt                    ,
    output  wire    [23:0]      out_rgb                     ,
    output  wire    [12:0]      out_src_w                   ,
    output  wire    [12:0]      out_src_h                   ,
    output  wire    [12:0]      out_dst_w                   ,
    output  wire    [12:0]      out_dst_h
);

localparam                      PH_IDLE                     = 2'd0;
localparam                      PH_P1                       = 2'd1;
localparam                      PH_GAP                      = 2'd2;
localparam                      PH_P2                       = 2'd3;

reg                             vs_d                        ;
wire                            vs_pos                      ;
reg             [3:0]           flush_cnt                   ;

reg             [12:0]          src_w_r                     ;
reg             [12:0]          src_h_r                     ;
reg             [12:0]          dst_w_r                     ;
reg             [12:0]          dst_h_r                     ;

reg             [1:0]           div_ph                      ;
reg             [4:0]           div_cnt                     ;
reg             [28:0]          div_dend                    ;
reg             [28:0]          div_quot                    ;
reg             [13:0]          div_rem                     ;
reg             [12:0]          div_sor                     ;
reg             [28:0]          x_step                      ;
reg             [28:0]          y_step                      ;
reg                             div_done                    ;

reg             [31:0]          x_acc                       ;
reg             [31:0]          pref_acc                    ;

reg             [12:0]          tag0, tag1, tag2, tag3      ;
reg             [3:0]           has                         ;
reg                             pend                        ;
reg             [12:0]          pend_y                      ;
reg             [1:0]           pend_bank                   ;
reg             [12:0]          pend_n                      ;
reg             [1:0]           pend_pair                   ;
reg             [1:0]           phase                       ;
reg             [2:0]           ack_s                       ;
reg                             feed_de                     ;
reg             [12:0]          feed_x                      ;
reg             [12:0]          feed_y                      ;
reg             [23:0]          feed_r1                     ;
reg             [23:0]          feed_r2                     ;
reg                             hold_vld                    ;
reg                             hold_vld_d                  ;
reg             [23:0]          hold_rgb                    ;
reg             [12:0]          hold_x                      ;
reg                             feed_de2                    ;
reg             [12:0]          feed_x2                     ;
reg             [12:0]          feed_y2                     ;
reg             [23:0]          feed_r1_2                   ;
reg             [23:0]          feed_r2_2                   ;
reg                             st_we                       ;
reg             [9:0]           st_wa                       ;
reg             [9:0]           st_ra                       ;
reg             [23:0]          st_di                       ;

reg                             took                        ;
reg             [12:0]          took_y                      ;
reg                             on_line                     ;
reg             [12:0]          disp_y0                     ;
reg             [12:0]          disp_y1                     ;
reg             [6:0]           disp_fy                     ;
reg             [1:0]           disp_b0                     ;
reg             [1:0]           disp_b1                     ;

reg                             wr_we                       ;
reg             [10:0]          wr_addr                     ;
reg             [23:0]          wr_data                     ;
reg             [1:0]           wr_bank                     ;

reg             [10:0]          rd_x0                       ;
reg             [10:0]          rd_x1                       ;
reg             [1:0]           rd_b0                       ;
reg             [1:0]           rd_b1                       ;

reg                             s0_on, s1_on, s2_on, s3_on, s4_on, s5_on, s6_on;
reg                             s0_de, s1_de, s2_de, s3_de, s4_de, s5_de, s6_de;
reg                             s0_vs, s1_vs, s2_vs, s3_vs, s4_vs, s5_vs, s6_vs;
reg                             s0_hs, s1_hs, s2_hs, s3_hs, s4_hs, s5_hs, s6_hs;
reg             [12:0]          s0_x, s1_x, s2_x, s3_x, s4_x, s5_x, s6_x;
reg             [12:0]          s0_y, s1_y, s2_y, s3_y, s4_y, s5_y, s6_y;
reg             [6:0]           s0_fx, s1_fx, s2_fx;
reg             [6:0]           s0_fy, s1_fy, s2_fy, s3_fy, s4_fy, s5_fy;
reg             [1:0]           s0_b0, s1_b0, s2_b0;
reg             [1:0]           s0_b1, s1_b1, s2_b1;

reg             [23:0]          near_t0, near_t1, near_t2;
reg             [23:0]          near_b0, near_b1, near_b2;
reg             [23:0]          near_v                      ;
reg                             s7_de, s7_vs, s7_hs         ;
reg             [12:0]          s7_x, s7_y                  ;
reg             [7:0]           out_r, out_g, out_b         ;

reg             [23:0]          hold_rgb_d                  ;
reg             [12:0]          hold_x_d                    ;
wire            [12:0]          dst_w_use                   ;
wire            [12:0]          dst_h_use                   ;
wire            [13:0]          rem_sh                      ;
wire                            ge                          ;
wire            [28:0]          quot_n                      ;
wire            [12:0]          pref_i0                     ;
wire            [12:0]          pref_i1                     ;
wire            [31:0]          next_acc                    ;
wire            [12:0]          next_i0                     ;
wire            [12:0]          next_i1                     ;
wire                            have_i0                     ;
wire                            have_i1                     ;
wire                            have_n0                     ;
wire                            have_n1                     ;
wire                            free_ok                     ;
wire            [1:0]           free_bank                   ;
wire            [12:0]          need_y                      ;
wire                            need_any                    ;
wire            [31:0]          x_now                       ;
wire            [12:0]          x_int                       ;
wire            [12:0]          x_int1                      ;
wire            [6:0]           x_frac                      ;
wire                            pix_on                      ;
wire            [23:0]          scale_rgb                   ;
wire                            scale_vs                    ;
wire                            scale_hs                    ;
wire                            scale_de                    ;
wire            [12:0]          scale_x                     ;
wire            [12:0]          scale_y                     ;
wire            [1:0]           cut_rd                      ;
wire                            cut_ode                     ;
wire            [12:0]          cut_ox                      ;
wire            [23:0]          cut_orgb                    ;
wire            [23:0]          st_dout                     ;
wire                            cut_de_w                    ;
wire            [12:0]          cut_x_w                     ;
wire            [12:0]          cut_y_w                     ;
wire            [23:0]          cut_r1_w                    ;
wire            [23:0]          cut_r2_w                    ;

wire            [23:0]          doa0, dob0, doa1, dob1, doa2, dob2, doa3, dob3;

assign vs_pos = in_vsync && !vs_d;
assign dst_w_use = enable ? dst_w : src_w;
assign dst_h_use = enable ? dst_h : src_h;
assign rem_sh = {div_rem[12:0], div_dend[28]};
assign ge     = rem_sh >= {1'b0, div_sor};
assign quot_n = {div_quot[27:0], ge};

assign pref_i0 = (pref_acc[28:16] >= src_h_r) ? (src_h_r - 13'd1) : pref_acc[28:16];
assign pref_i1 = (pref_i0 + 13'd1 >= src_h_r) ? (src_h_r - 13'd1) : (pref_i0 + 13'd1);
assign next_acc = pref_acc + {3'b0, y_step};
assign next_i0 = (next_acc[28:16] >= src_h_r) ? (src_h_r - 13'd1) : next_acc[28:16];
assign next_i1 = (next_i0 + 13'd1 >= src_h_r) ? (src_h_r - 13'd1) : (next_i0 + 13'd1);

wire [12:0] cur_y = pref_acc[15] ? pref_i1 : pref_i0;
wire [12:0] nxt_y = next_acc[15] ? next_i1 : next_i0;
assign have_i0 = (has[0] && tag0 == cur_y) || (has[1] && tag1 == cur_y) ||
                 (has[2] && tag2 == cur_y) || (has[3] && tag3 == cur_y);
assign have_i1 = have_i0;
assign have_n0 = (has[0] && tag0 == nxt_y) || (has[1] && tag1 == nxt_y) ||
                 (has[2] && tag2 == nxt_y) || (has[3] && tag3 == nxt_y);
assign have_n1 = have_n0;

wire take_line = run && div_done && in_de && (in_xcnt == 13'd0) && !took &&
                   (in_ycnt >= 13'd1) && (in_ycnt <= dst_h_r);
wire line_lock = on_line || (take_line && have_i0);
wire [6:0] use_fy = take_line ? pref_acc[15:9] : disp_fy;
wire [1:0] use_b0 = take_line ? bank_of(cur_y) : disp_b0;
wire [1:0] use_b1 = use_b0;
wire [3:0] bank_busy;
assign bank_busy[0] = (line_lock && ((use_b0 == 2'd0) || (use_b1 == 2'd0))) || (pend && pend_bank == 2'd0);
assign bank_busy[1] = (line_lock && ((use_b0 == 2'd1) || (use_b1 == 2'd1))) || (pend && pend_bank == 2'd1);
assign bank_busy[2] = (line_lock && ((use_b0 == 2'd2) || (use_b1 == 2'd2))) || (pend && pend_bank == 2'd2);
assign bank_busy[3] = (line_lock && ((use_b0 == 2'd3) || (use_b1 == 2'd3))) || (pend && pend_bank == 2'd3);

wire [3:0] bank_keep;
assign bank_keep[0] = has[0] && ((tag0 == cur_y) || (tag0 == nxt_y));
assign bank_keep[1] = has[1] && ((tag1 == cur_y) || (tag1 == nxt_y));
assign bank_keep[2] = has[2] && ((tag2 == cur_y) || (tag2 == nxt_y));
assign bank_keep[3] = has[3] && ((tag3 == cur_y) || (tag3 == nxt_y));

assign free_ok = !(bank_busy[0] || bank_keep[0]) || !(bank_busy[1] || bank_keep[1]) ||
                 !(bank_busy[2] || bank_keep[2]) || !(bank_busy[3] || bank_keep[3]);
assign free_bank = !(bank_busy[0] || bank_keep[0]) ? 2'd0 :
                   (!(bank_busy[1] || bank_keep[1]) ? 2'd1 :
                   (!(bank_busy[2] || bank_keep[2]) ? 2'd2 : 2'd3));

assign need_any = div_done && run && !pend && free_ok && (!have_i0 || !have_n0);
assign need_y = !have_i0 ? cur_y : nxt_y;

assign x_now  = (in_de && (in_xcnt == 13'd0)) ? 32'd0 : x_acc;
assign x_int  = (x_now[28:16] >= src_w_r) ? (src_w_r - 13'd1) : x_now[28:16];
assign x_int1 = (x_int + 13'd1 >= src_w_r) ? (src_w_r - 13'd1) : (x_int + 13'd1);
assign x_frac = x_now[15:9];
assign pix_on = (take_line ? (have_i0 && have_i1) : on_line) && in_de &&
                 (in_xcnt < dst_w_r) && (in_ycnt >= 13'd1) && (in_ycnt <= dst_h_r);

assign pix_re = pend && !pix_empty && ((phase == PH_P1) || (phase == PH_P2));
assign cut_de_w = (pend_pair == 2'd2) ? feed_de2 : feed_de;
assign cut_x_w  = (pend_pair == 2'd2) ? feed_x2  : feed_x;
assign cut_y_w  = (pend_pair == 2'd2) ? feed_y2  : feed_y;
assign cut_r1_w = (pend_pair == 2'd2) ? feed_r1_2 : feed_r1;
assign cut_r2_w = (pend_pair == 2'd2) ? feed_r2_2 : feed_r2;

function automatic [12:0] clamp_w;
    input [12:0] v;
    begin
        if(v == 13'd0) clamp_w = 13'd1;
        else if(v > 13'd1280) clamp_w = 13'd1280;
        else clamp_w = v;
    end
endfunction

function automatic [12:0] clamp_h;
    input [12:0] v;
    begin
        if(v == 13'd0) clamp_h = 13'd1;
        else if(v > 13'd720) clamp_h = 13'd720;
        else clamp_h = v;
    end
endfunction

function automatic [1:0] bank_of;
    input [12:0] yv;
    begin
        if(has[0] && tag0 == yv) bank_of = 2'd0;
        else if(has[1] && tag1 == yv) bank_of = 2'd1;
        else if(has[2] && tag2 == yv) bank_of = 2'd2;
        else bank_of = 2'd3;
    end
endfunction

wire [23:0] cap_top_a = (s2_b0 == 2'd0) ? doa0 : (s2_b0 == 2'd1) ? doa1 : (s2_b0 == 2'd2) ? doa2 : doa3;
wire [23:0] cap_top_b = (s2_b0 == 2'd0) ? dob0 : (s2_b0 == 2'd1) ? dob1 : (s2_b0 == 2'd2) ? dob2 : dob3;
wire [23:0] cap_bot_a = (s2_b1 == 2'd0) ? doa0 : (s2_b1 == 2'd1) ? doa1 : (s2_b1 == 2'd2) ? doa2 : doa3;
wire [23:0] cap_bot_b = (s2_b1 == 2'd0) ? dob0 : (s2_b1 == 2'd1) ? dob1 : (s2_b1 == 2'd2) ? dob2 : dob3;

tdp_scale_line u_line0(
    .doa(doa0), .dia(wr_data), .addra((wr_we && wr_bank == 2'd0) ? wr_addr : rd_x0),
    .clka(clk), .wea(wr_we && wr_bank == 2'd0), .rsta(reset),
    .dob(dob0), .dib(24'd0), .addrb(rd_x1), .clkb(clk), .web(1'b0), .rstb(reset)
);
tdp_scale_line u_line1(
    .doa(doa1), .dia(wr_data), .addra((wr_we && wr_bank == 2'd1) ? wr_addr : rd_x0),
    .clka(clk), .wea(wr_we && wr_bank == 2'd1), .rsta(reset),
    .dob(dob1), .dib(24'd0), .addrb(rd_x1), .clkb(clk), .web(1'b0), .rstb(reset)
);
tdp_scale_line u_line2(
    .doa(doa2), .dia(wr_data), .addra((wr_we && wr_bank == 2'd2) ? wr_addr : rd_x0),
    .clka(clk), .wea(wr_we && wr_bank == 2'd2), .rsta(reset),
    .dob(dob2), .dib(24'd0), .addrb(rd_x1), .clkb(clk), .web(1'b0), .rstb(reset)
);
tdp_scale_line u_line3(
    .doa(doa3), .dia(wr_data), .addra((wr_we && wr_bank == 2'd3) ? wr_addr : rd_x0),
    .clka(clk), .wea(wr_we && wr_bank == 2'd3), .rsta(reset),
    .dob(dob3), .dib(24'd0), .addrb(rd_x1), .clkb(clk), .web(1'b0), .rstb(reset)
);

always@(posedge clk) begin
    if(reset) begin
        vs_d <= 1'b0;
        flush_cnt <= 4'd0;
        flush <= 1'b0;
        run <= 1'b0;
        src_w_r <= 13'd640;
        src_h_r <= 13'd480;
        dst_w_r <= 13'd640;
        dst_h_r <= 13'd480;
        div_ph <= 2'd0;
        div_cnt <= 5'd0;
        div_dend <= 29'd0;
        div_quot <= 29'd0;
        div_rem <= 14'd0;
        div_sor <= 13'd1;
        x_step <= 29'd0;
        y_step <= 29'd0;
        div_done <= 1'b0;
        x_acc <= 32'd0;
        pref_acc <= 32'd0;
        tag0 <= 13'd0; tag1 <= 13'd0; tag2 <= 13'd0; tag3 <= 13'd0;
        has <= 4'd0;
        pend <= 1'b0;
        pend_y <= 13'd0;
        pend_bank <= 2'd0;
        pend_n <= 13'd0;
        ack_s <= 3'd0;
        line_req <= 1'b0;
        line_y <= 13'd0;
        line_bank <= 2'd0;
        took <= 1'b0;
        took_y <= 13'd0;
        on_line <= 1'b0;
        disp_y0 <= 13'd0;
        disp_y1 <= 13'd0;
        disp_fy <= 7'd0;
        disp_b0 <= 2'd0;
        disp_b1 <= 2'd0;
        wr_we <= 1'b0;
        wr_addr <= 11'd0;
        wr_data <= 24'd0;
        wr_bank <= 2'd0;
        rd_x0 <= 11'd0;
        rd_x1 <= 11'd0;
        rd_b0 <= 2'd0;
        rd_b1 <= 2'd0;
        s0_on <= 0; s1_on <= 0; s2_on <= 0; s3_on <= 0; s4_on <= 0; s5_on <= 0; s6_on <= 0;
        s0_de <= 0; s1_de <= 0; s2_de <= 0; s3_de <= 0; s4_de <= 0; s5_de <= 0; s6_de <= 0; s7_de <= 0;
        s0_vs <= 0; s1_vs <= 0; s2_vs <= 0; s3_vs <= 0; s4_vs <= 0; s5_vs <= 0; s6_vs <= 0;
        s0_hs <= 0; s1_hs <= 0; s2_hs <= 0; s3_hs <= 0; s4_hs <= 0; s5_hs <= 0; s6_hs <= 0;
        s0_x <= 0; s1_x <= 0; s2_x <= 0; s3_x <= 0; s4_x <= 0; s5_x <= 0; s6_x <= 0;
        s0_y <= 0; s1_y <= 0; s2_y <= 0; s3_y <= 0; s4_y <= 0; s5_y <= 0; s6_y <= 0;
        s0_fx <= 0; s1_fx <= 0; s2_fx <= 0;
        s0_fy <= 0; s1_fy <= 0; s2_fy <= 0; s3_fy <= 0; s4_fy <= 0; s5_fy <= 0;
        s7_vs <= 0; s7_hs <= 0; s7_x <= 0; s7_y <= 0;
        s0_b0 <= 0; s1_b0 <= 0; s2_b0 <= 0;
        s0_b1 <= 0; s1_b1 <= 0; s2_b1 <= 0;
        near_t0 <= 0; near_t1 <= 0; near_t2 <= 0;
        near_b0 <= 0; near_b1 <= 0; near_b2 <= 0;
        near_v <= 0;
        out_r <= 0; out_g <= 0; out_b <= 0;
        pend_pair <= 2'd0;
        phase <= PH_IDLE;
        line_pic <= 1'b0;
        feed_de <= 1'b0;
        feed_x <= 13'd0;
        feed_y <= 13'd0;
        feed_r1 <= 24'd0;
        feed_r2 <= 24'd0;
        hold_vld <= 1'b0;
        hold_vld_d <= 1'b0;
        hold_rgb <= 24'd0;
        hold_rgb_d <= 24'd0;
        hold_x <= 13'd0;
        hold_x_d <= 13'd0;
        feed_de2 <= 1'b0;
        feed_x2 <= 13'd0;
        feed_y2 <= 13'd0;
        feed_r1_2 <= 24'd0;
        feed_r2_2 <= 24'd0;
        st_we <= 1'b0;
        st_wa <= 10'd0;
        st_ra <= 10'd0;
        st_di <= 24'd0;
    end
    else begin
        vs_d <= in_vsync;
        ack_s <= {ack_s[1:0], line_ack};

        if(flush_cnt != 4'd0) begin
            flush_cnt <= flush_cnt - 4'd1;
            flush <= 1'b1;
        end
        else
            flush <= 1'b0;

        if(vs_pos) begin
            src_w_r <= clamp_w(src_w);
            src_h_r <= clamp_h(src_h);
            dst_w_r <= clamp_w(dst_w_use);
            dst_h_r <= clamp_h(dst_h_use);
            run <= (src_w != 13'd0) && (src_h != 13'd0) &&
                   (dst_w_use != 13'd0) && (dst_h_use != 13'd0);
            flush_cnt <= 4'd8;
            div_done <= 1'b0;
            div_ph <= 2'd0;
            div_cnt <= 5'd0;
            div_rem <= 14'd0;
            div_quot <= 29'd0;
            div_dend <= {clamp_w(src_w), 16'b0};
            div_sor <= clamp_w(dst_w_use);
            phase <= PH_IDLE;
            pend_pair <= 2'd0;
            line_pic <= 1'b0;
            hold_vld <= 1'b0;
            hold_vld_d <= 1'b0;
            feed_de <= 1'b0;
            feed_de2 <= 1'b0;
            pref_acc <= 32'd0;
            x_acc <= 32'd0;
            has <= 4'd0;
            pend <= 1'b0;
            pend_n <= 13'd0;
            line_req <= 1'b0;
            took <= 1'b0;
            on_line <= 1'b0;
        end
        else if(run && !div_done) begin
            if(div_cnt == 5'd28) begin
                if(div_ph == 2'd0) begin
                    x_step <= quot_n;
                    div_ph <= 2'd1;
                    div_cnt <= 5'd0;
                    div_rem <= 14'd0;
                    div_quot <= 29'd0;
                    div_dend <= {src_h_r, 16'b0};
                    div_sor <= dst_h_r;
                end
                else begin
                    y_step <= quot_n;
                    div_done <= 1'b1;
                end
            end
            else begin
                div_rem <= ge ? (rem_sh - {1'b0, div_sor}) : rem_sh;
                div_quot <= quot_n;
                div_dend <= {div_dend[27:0], 1'b0};
                div_cnt <= div_cnt + 5'd1;
            end
        end

        feed_de <= 1'b0;
        hold_vld <= 1'b0;
        st_we <= 1'b0;
        hold_vld_d <= hold_vld;
        hold_rgb_d <= hold_rgb;
        hold_x_d <= hold_x;
        feed_de2 <= hold_vld_d;
        feed_x2 <= hold_x_d;
        feed_y2 <= pend_y + 13'd1;
        feed_r1_2 <= st_dout;
        feed_r2_2 <= hold_rgb_d;

        if(need_any && !flush && !vs_pos && (flush_cnt == 4'd0)) begin
            line_req <= 1'b1;
            line_y <= need_y;
            line_bank <= free_bank;
            line_pic <= (cut_rd == 2'd1);
            pend <= 1'b1;
            pend_y <= need_y;
            pend_bank <= free_bank;
            pend_n <= 13'd0;
            pend_pair <= cut_rd;
            phase <= PH_P1;
            has[free_bank] <= 1'b0;
            hold_vld_d <= 1'b0;
            feed_de2 <= 1'b0;
        end
        else if(!vs_pos && !flush && (phase == PH_GAP) && pix_empty && !line_req) begin
            line_req <= 1'b1;
            line_y <= pend_y;
            line_bank <= pend_bank;
            line_pic <= 1'b1;
        end
        if(line_req && ack_s[2])
            line_req <= 1'b0;
        if(!vs_pos && (phase == PH_GAP) && line_req && ack_s[2]) begin
            phase <= PH_P2;
            pend_n <= 13'd0;
        end

        if(!vs_pos && !flush && pix_valid && (phase == PH_P1) && (pend_pair == 2'd2)) begin
            st_we <= 1'b1;
            st_wa <= pend_n[9:0];
            st_di <= pix_data;
            if(pend_n + 13'd1 == src_w_r)
                phase <= PH_GAP;
            else
                pend_n <= pend_n + 13'd1;
        end
        else if(!vs_pos && !flush && pix_valid && (phase == PH_P1)) begin
            feed_de <= 1'b1;
            feed_x <= pend_n;
            feed_y <= pend_y + 13'd1;
            feed_r1 <= (pend_pair == 2'd1) ? 24'd0 : pix_data;
            feed_r2 <= (pend_pair == 2'd1) ? pix_data : 24'd0;
            if(pend_n + 13'd1 == src_w_r)
                phase <= PH_IDLE;
            else
                pend_n <= pend_n + 13'd1;
        end
        else if(!vs_pos && !flush && pix_valid && (phase == PH_P2)) begin
            hold_vld <= 1'b1;
            hold_rgb <= pix_data;
            hold_x <= pend_n;
            st_ra <= pend_n[9:0];
            if(pend_n + 13'd1 == src_w_r)
                phase <= PH_IDLE;
            else
                pend_n <= pend_n + 13'd1;
        end

        wr_we <= 1'b0;
        if(pend && cut_ode && !vs_pos && !flush) begin
            wr_we <= 1'b1;
            wr_bank <= pend_bank;
            wr_addr <= cut_ox[10:0];
            wr_data <= cut_orgb;
            if(cut_ox + 13'd1 == src_w_r) begin
                pend <= 1'b0;
                phase <= PH_IDLE;
                has[pend_bank] <= 1'b1;
                if(pend_bank == 2'd0) tag0 <= pend_y;
                if(pend_bank == 2'd1) tag1 <= pend_y;
                if(pend_bank == 2'd2) tag2 <= pend_y;
                if(pend_bank == 2'd3) tag3 <= pend_y;
            end
        end

        if(vs_pos) begin
            hold_vld   <= 1'b0;
            hold_vld_d <= 1'b0;
            feed_de    <= 1'b0;
            feed_de2   <= 1'b0;
            st_we      <= 1'b0;
            phase      <= PH_IDLE;
        end

        if(in_ycnt != took_y)
            took <= 1'b0;
        if(run && div_done && in_de && (in_xcnt == 13'd0) && !took &&
           (in_ycnt >= 13'd1) && (in_ycnt <= dst_h_r)) begin
            took <= 1'b1;
            took_y <= in_ycnt;
            on_line <= have_i0;
            disp_y0 <= cur_y;
            disp_y1 <= cur_y;
            disp_fy <= pref_acc[15:9];
            disp_b0 <= bank_of(cur_y);
            disp_b1 <= bank_of(cur_y);
            pref_acc <= pref_acc + {3'b0, y_step};
        end

        if(pix_on)
            x_acc <= x_now + {3'b0, x_step};
        else if(in_de && (in_xcnt == 13'd0))
            x_acc <= 32'd0;

        rd_x0 <= x_int[10:0];
        rd_x1 <= x_int1[10:0];
        rd_b0 <= use_b0;
        rd_b1 <= use_b1;

        s0_on <= pix_on;
        s0_de <= in_de;
        s0_vs <= in_vsync;
        s0_hs <= in_hsync;
        s0_x  <= in_xcnt;
        s0_y  <= in_ycnt;
        s0_fx <= x_frac;
        s0_fy <= use_fy;
        s0_b0 <= use_b0;
        s0_b1 <= use_b1;

        s1_on <= s0_on; s1_de <= s0_de; s1_vs <= s0_vs; s1_hs <= s0_hs;
        s1_x <= s0_x; s1_y <= s0_y; s1_fx <= s0_fx; s1_fy <= s0_fy;
        s1_b0 <= s0_b0; s1_b1 <= s0_b1;

        s2_on <= s1_on; s2_de <= s1_de; s2_vs <= s1_vs; s2_hs <= s1_hs;
        s2_x <= s1_x; s2_y <= s1_y; s2_fx <= s1_fx; s2_fy <= s1_fy;
        s2_b0 <= s1_b0; s2_b1 <= s1_b1;

        near_t0 <= s2_fx[6] ? cap_top_b : cap_top_a;
        near_b0 <= s2_fx[6] ? cap_bot_b : cap_bot_a;
        s3_on <= s2_on; s3_de <= s2_de; s3_vs <= s2_vs; s3_hs <= s2_hs;
        s3_x <= s2_x; s3_y <= s2_y; s3_fy <= s2_fy;

        near_t1 <= near_t0;
        near_b1 <= near_b0;
        s4_on <= s3_on; s4_de <= s3_de; s4_vs <= s3_vs; s4_hs <= s3_hs;
        s4_x <= s3_x; s4_y <= s3_y; s4_fy <= s3_fy;

        near_t2 <= near_t1;
        near_b2 <= near_b1;
        s5_on <= s4_on; s5_de <= s4_de; s5_vs <= s4_vs; s5_hs <= s4_hs;
        s5_x <= s4_x; s5_y <= s4_y; s5_fy <= s4_fy;

        near_v <= s5_fy[6] ? near_b2 : near_t2;
        s6_on <= s5_on; s6_de <= s5_de; s6_vs <= s5_vs; s6_hs <= s5_hs;
        s6_x <= s5_x; s6_y <= s5_y;

        if(s6_on) begin
            out_r <= near_v[23:16];
            out_g <= near_v[15:8];
            out_b <= near_v[7:0];
        end
        else begin
            out_r <= 8'd0;
            out_g <= 8'd0;
            out_b <= 8'd0;
        end
        s7_de <= s6_de; s7_vs <= s6_vs; s7_hs <= s6_hs;
        s7_x <= s6_x; s7_y <= s6_y;
    end
end

assign scale_vs  = s7_vs;
assign scale_hs  = s7_hs;
assign scale_de  = s7_de;
assign scale_x   = s7_x;
assign scale_y   = s7_y;
assign scale_rgb = {out_r, out_g, out_b};

assign out_vsync = scale_vs;
assign out_hsync = scale_hs;
assign out_de    = scale_de;
assign out_xcnt  = scale_x;
assign out_ycnt  = scale_y;
assign out_rgb   = scale_rgb;
assign out_src_w = src_w_r;
assign out_src_h = src_h_r;
assign out_dst_w = dst_w_r;
assign out_dst_h = dst_h_r;

simple_dual_ram #(
    .RAM_WIDTH                  (24                         ),
    .RAM_DEPTH                  (1024                       ),
    .PERFORMENCE                ("LOW"                      )
)u_stage(
    .clka                       (clk                        ),
    .wea                        (st_we                      ),
    .dina                       (st_di                      ),
    .addra                      (st_wa                      ),
    .addrb                      (st_ra                      ),
    .doutb                      (st_dout                    )
);

VPU_CUT_TO u_cut(
    .clk                        (clk                        ),
    .reset                      (reset                      ),
    .cut_to_valid_width         (src_w                      ),
    .cut_to_valid_height        (src_h                      ),
    .cut_to_disable             (cut_disable                ),
    .cut_to_mode_set            (cut_mode                   ),
    .cut_to_speed_set           (cut_speed                  ),
    .cut_to_in_pchange          (cut_pchange                ),
    .cut_to_in_vsync            (in_vsync                   ),
    .cut_to_in_hsync            (in_hsync                   ),
    .cut_to_in_de               (cut_de_w                   ),
    .cut_to_in_xcnt             (cut_x_w                    ),
    .cut_to_in_ycnt             (cut_y_w                    ),
    .cut_to_in_rgb1             (cut_r1_w                   ),
    .cut_to_in_rgb2             (cut_r2_w                   ),
    .cut_to_out_vsync           (                           ),
    .cut_to_out_hsync           (                           ),
    .cut_to_out_de              (cut_ode                    ),
    .cut_to_out_xcnt            (cut_ox                     ),
    .cut_to_out_ycnt            (                           ),
    .cut_to_out_rgb             (cut_orgb                   ),
    .cut_to_out_done            (cut_done                   ),
    .cut_to_active              (cut_active                 ),
    .cut_to_rd                  (cut_rd                     )
);

endmodule
