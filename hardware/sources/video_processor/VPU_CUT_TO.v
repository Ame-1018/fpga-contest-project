`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Create Date: 2026/10/08 09:21:17
// Design Name: 
// Module Name: VPU_CUT_TO
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 八种转场。rgb1 为当前图，rgb2 为下一张。
//              0 硬切，1 整帧淡入，2 左滑，3 右滑，4 百叶窗，5 溶解，6 中心展开，7 经黑场。
//              cut_to_speed_set：0/1/2/3 对应 16/32/64/128 帧。模式和速度在场同步锁存。
//              cut_to_in_pchange 为异步脉冲，锁存到下一场同步再开始。
// Dependencies: dsp_mul_u8x9, dsp_mul_u9x10
// Revision:
// Revision 0.01 - File Created
// Additional Comments: 边缘和黑场的积先寄存，混合系数再打一拍，像素积再打一拍。
//              PIX_LAT=3。几何量先打一拍再算系数，disable=1 时按该拍数透传 rgb1。
//              x 从 0 起且小于宽度、y 从 1 到高度为有效区，区外输出黑。
//              宽高在场同步锁存。左右滑跨度是宽加 64，右缘是宽减 1。
//              中心是宽的一半，垂直半宽是高减去高的一半。百叶窗跨度仍是 80。
//              跨度可以到 2047。dsp_mul_u9x10 只乘低 10 位，第 11 位用 prog 左移 10 位相加。
// 
//////////////////////////////////////////////////////////////////////////////////

module VPU_CUT_TO(
    input   wire                clk                         ,
    input   wire                reset                       ,

    input   wire    [12:0]      cut_to_valid_width          ,
    input   wire    [12:0]      cut_to_valid_height         ,

    input   wire                cut_to_disable              ,

    input   wire    [2:0]       cut_to_mode_set             ,
    input   wire    [1:0]       cut_to_speed_set            ,

    input   wire                cut_to_in_pchange           ,
    input   wire                cut_to_in_vsync             ,
    input   wire                cut_to_in_hsync             ,
    input   wire                cut_to_in_de                ,
    input   wire    [12:0]      cut_to_in_xcnt              ,
    input   wire    [12:0]      cut_to_in_ycnt              ,
    input   wire    [23:0]      cut_to_in_rgb1              ,
    input   wire    [23:0]      cut_to_in_rgb2              ,

    output  wire                cut_to_out_vsync            ,
    output  wire                cut_to_out_hsync            ,
    output  wire                cut_to_out_de               ,
    output  wire    [12:0]      cut_to_out_xcnt             ,
    output  wire    [12:0]      cut_to_out_ycnt             ,
    output  wire    [23:0]      cut_to_out_rgb              ,
    output  reg                 cut_to_out_done             ,
    output  wire                cut_to_active               ,
    // 0 只读当前图，1 只读下一张，2 同一源行两张都读。
    output  wire    [1:0]       cut_to_rd
);

localparam                      BAND_SLIDE                  = 14'sd64;
localparam                      BAND_BLIND                  = 14'sd16;
localparam                      SPAN_BLIND                  = 11'd80;
localparam                      PIX_LAT                     = 3;

reg     [2:0]                   pchange_sync                ;
reg                             pchange_pending             ;
reg                             vsync_d                     ;
wire                            pchange_pos                 ;
wire                            vsync_pos                   ;

reg                             cut_busy                    ;
reg                             release_prog                ;
reg     [2:0]                   mode_latch                  ;
reg     [1:0]                   speed_latch                 ;
reg     [7:0]                   frame_latch                 ;
reg     [4:0]                   step_latch                  ;
reg     [8:0]                   prog                        ;
reg     [7:0]                   fade_i                      ;
reg     [12:0]                  width_l                     ;
reg     [12:0]                  height_l                    ;

reg     [2:0]                   cut_to_in_pchange_r3        ;
wire                            cut_to_in_pchange_pos       ;
wire                            cut_to_in_pchange_hold      ;
reg                             cut_to_in_pchange_end       ;

assign pchange_pos = pchange_sync[1] && !pchange_sync[2];
assign vsync_pos   = cut_to_in_vsync && !vsync_d;
assign cut_to_in_pchange_pos  = pchange_pos;
assign cut_to_in_pchange_hold = pchange_pending;

always@(posedge clk) begin
    if(reset) begin
        pchange_sync    <= 3'd0;
        vsync_d         <= 1'b0;
        pchange_pending <= 1'b0;
        cut_busy        <= 1'b0;
        release_prog    <= 1'b0;
        mode_latch      <= 3'd0;
        speed_latch     <= 2'd1;
        frame_latch     <= 8'd32;
        step_latch      <= 5'd8;
        prog            <= 9'd0;
        fade_i          <= 8'd0;
        width_l         <= 13'd640;
        height_l        <= 13'd480;
        cut_to_out_done <= 1'b0;
        cut_to_in_pchange_end <= 1'b0;
        cut_to_in_pchange_r3  <= 3'd0;
    end
    else begin
        pchange_sync <= {pchange_sync[1:0], cut_to_in_pchange};
        cut_to_in_pchange_r3 <= {pchange_sync[1:0], cut_to_in_pchange};
        vsync_d      <= cut_to_in_vsync;
        cut_to_out_done <= 1'b0;
        cut_to_in_pchange_end <= 1'b0;

        if(vsync_pos) begin
            width_l  <= cut_to_valid_width;
            height_l <= cut_to_valid_height;
        end

        if(vsync_pos && cut_busy) begin
            if(pchange_pos) begin
                pchange_pending <= 1'b1;
            end
            if(mode_latch == 3'd7) begin
                if(fade_i >= frame_latch) begin
                    cut_busy <= 1'b0;
                    release_prog <= 1'b1;
                    cut_to_out_done <= 1'b1;
                    cut_to_in_pchange_end <= 1'b1;
                end
                else begin
                    fade_i <= fade_i + 1'b1;
                    if(fade_i + 1'b1 >= frame_latch) begin
                        cut_busy <= 1'b0;
                        release_prog <= 1'b1;
                        cut_to_out_done <= 1'b1;
                        cut_to_in_pchange_end <= 1'b1;
                    end
                end
            end
            else if(prog + {4'd0, step_latch} >= 9'd256) begin
                prog <= 9'd256;
                cut_busy <= 1'b0;
                release_prog <= 1'b1;
                cut_to_out_done <= 1'b1;
                cut_to_in_pchange_end <= 1'b1;
            end
            else begin
                prog <= prog + {4'd0, step_latch};
            end
        end
        else if(vsync_pos && (pchange_pending || pchange_pos)) begin
            mode_latch  <= cut_to_mode_set;
            speed_latch <= cut_to_speed_set;
            case(cut_to_speed_set)
                2'd0: begin frame_latch <= 8'd16;  step_latch <= 5'd16; end
                2'd1: begin frame_latch <= 8'd32;  step_latch <= 5'd8;  end
                2'd2: begin frame_latch <= 8'd64;  step_latch <= 5'd4;  end
                default: begin frame_latch <= 8'd128; step_latch <= 5'd2; end
            endcase
            pchange_pending <= 1'b0;
            release_prog    <= 1'b0;
            if(cut_to_mode_set == 3'd0) begin
                prog     <= 9'd256;
                fade_i   <= 8'd1;
                cut_busy <= 1'b0;
                release_prog <= 1'b1;
                cut_to_out_done <= 1'b1;
                cut_to_in_pchange_end <= 1'b1;
            end
            else begin
                cut_busy <= 1'b1;
                fade_i   <= 8'd1;
                case(cut_to_speed_set)
                    2'd0: prog <= 9'd16;
                    2'd1: prog <= 9'd8;
                    2'd2: prog <= 9'd4;
                    default: prog <= 9'd2;
                endcase
            end
        end
        else if(vsync_pos && release_prog && !cut_busy) begin
            prog         <= 9'd0;
            release_prog <= 1'b0;
        end
        else if(pchange_pos) begin
            pchange_pending <= 1'b1;
        end
    end
end

wire    [13:0]                  span_slide_w                ;
wire    [12:0]                  half_w                      ;
wire    [12:0]                  half_h                      ;
wire    [12:0]                  half_max                    ;
wire    [13:0]                  span_box_w                  ;
wire    [10:0]                  span_slide                  ;
wire    [10:0]                  span_box                    ;
wire    [10:0]                  span_sel                    ;
assign half_w = {1'b0, width_l[12:1]};
assign half_h = height_l - {1'b0, height_l[12:1]};
assign half_max = (half_w >= half_h) ? half_w : half_h;
assign span_slide_w = {1'b0, width_l} + 14'd64;
assign span_box_w = {1'b0, half_max} + 14'd64;
assign span_slide = (span_slide_w > 14'd2047) ? 11'd2047 : span_slide_w[10:0];
assign span_box   = (span_box_w   > 14'd2047) ? 11'd2047 : span_box_w[10:0];
assign span_sel = (mode_latch == 3'd4) ? SPAN_BLIND :
                  (mode_latch == 3'd6) ? span_box   : span_slide;
// 跨度一帧才变一次。边缘和黑场系数在场消隐里逐位相乘，不再占 DSP。
reg             [10:0]          span_q                      ;

reg     [12:0]                  edge_pix_q                  ;
reg     [8:0]                   black_level_q               ;
reg                             coef_arm                    ;
reg             [1:0]           coef_ph                     ;
reg             [3:0]           coef_bit                    ;
reg             [18:0]          coef_acc                    ;
reg             [18:0]          coef_a                      ;
reg             [18:0]          coef_b                      ;
reg             [8:0]           prog_s                      ;
reg                             span10_s                    ;
reg             [7:0]           black_a_s                   ;
reg             [8:0]           step_s                      ;
reg             [18:0]          coef_sum                    ;
wire    [5:0]                   step_black                  ;
wire    [7:0]                   black_a                     ;
wire    [7:0]                   half_frame                  ;

assign half_frame = {1'b0, frame_latch[7:1]};
assign step_black = {step_latch, 1'b0};
assign black_a = (fade_i <= half_frame) ? fade_i : (fade_i - half_frame);
wire    [18:0]                  bit_sum                     ;
wire    [18:0]                  edge_tot                    ;
assign bit_sum  = coef_acc + (coef_a[0] ? coef_b : 19'd0);
assign edge_tot = bit_sum + (span10_s ? {prog_s, 10'd0} : 19'd0);

always@(posedge clk) begin
    if(reset) begin
        coef_arm     <= 1'b0;
        coef_ph      <= 2'd0;
        coef_bit     <= 4'd0;
        coef_acc     <= 19'd0;
        coef_a       <= 19'd0;
        coef_b       <= 19'd0;
        coef_sum     <= 19'd0;
        prog_s       <= 9'd0;
        span10_s     <= 1'b0;
        black_a_s    <= 8'd0;
        step_s       <= 9'd0;
        edge_pix_q   <= 13'd0;
        black_level_q<= 9'd0;
    end
    else begin
        coef_arm <= vsync_pos;
        if((coef_ph == 2'd0) && coef_arm) begin
            coef_ph   <= 2'd1;
            coef_bit  <= 4'd0;
            coef_acc  <= 19'd0;
            coef_a    <= {10'd0, prog};
            coef_b    <= {9'd0, span_sel[9:0]};
            prog_s    <= prog;
            span10_s  <= span_sel[10];
            black_a_s <= black_a;
            step_s    <= {3'b0, step_black};
        end
        else if((coef_ph == 2'd1) && (coef_bit == 4'd8)) begin
            coef_sum <= bit_sum;
            edge_pix_q <= {2'd0, edge_tot[18:8]};
            coef_ph  <= 2'd2;
            coef_bit <= 4'd0;
            coef_acc <= 19'd0;
            coef_a   <= {11'd0, black_a_s};
            coef_b   <= {10'd0, step_s};
        end
        else if((coef_ph == 2'd2) && (coef_bit == 4'd7)) begin
            coef_sum <= bit_sum;
            black_level_q <= (bit_sum > 19'd256) ? 9'd256 : bit_sum[8:0];
            coef_ph <= 2'd0;
        end
        else if(coef_ph != 2'd0) begin
            if(coef_a[0])
                coef_acc <= coef_acc + coef_b;
            coef_a   <= coef_a >> 1;
            coef_b   <= coef_b << 1;
            coef_bit <= coef_bit + 4'd1;
        end
    end
end

reg     [8:0]                   coef1_q                     ;
reg     [8:0]                   coef2_q                     ;
reg     [23:0]                  rgb1_d                      ;
reg     [23:0]                  rgb2_d                      ;
reg     [23:0]                  rgb1_d2                     ;
reg     [23:0]                  rgb2_d2                     ;
wire signed [13:0]              edge_s                      ;
wire signed [13:0]              x_s                         ;
wire signed [13:0]              y_s                         ;
wire signed [13:0]              dx_left                     ;
wire signed [13:0]              dx_right                    ;
wire signed [13:0]              dx_blind                    ;
wire signed [13:0]              dx_box                      ;
wire        [12:0]              abs_x                       ;
wire        [12:0]              abs_y                       ;
wire        [12:0]              cheb                        ;
wire        [7:0]               hash                        ;
reg signed  [13:0]              dx_left_q                   ;
reg signed  [13:0]              dx_right_q                  ;
reg signed  [13:0]              dx_blind_q                  ;
reg signed  [13:0]              dx_box_q                    ;
reg         [7:0]               hash_q                      ;
reg                             x_past_pic_q                ;
wire        [8:0]               k_pix                       ;
wire        [8:0]               coef1                       ;
wire        [8:0]               coef2                       ;

wire        [12:0]              box_cx                      ;
wire        [12:0]              box_cy                      ;
wire signed [13:0]              right_s                     ;
assign box_cx = {1'b0, width_l[12:1]};
assign box_cy = {1'b0, height_l[12:1]};
assign right_s = {1'b0, width_l} - 14'sd1;
assign edge_s = {1'b0, edge_pix_q};
assign x_s    = {1'b0, cut_to_in_xcnt};
assign y_s    = {1'b0, cut_to_in_ycnt};
assign dx_left  = edge_s - x_s;
assign dx_right = x_s - (right_s - edge_s);
assign dx_blind = edge_s - {8'd0, cut_to_in_xcnt[5:0]};
assign abs_x = (cut_to_in_xcnt >= box_cx) ? (cut_to_in_xcnt - box_cx) : (box_cx - cut_to_in_xcnt);
assign abs_y = (cut_to_in_ycnt >= box_cy) ? (cut_to_in_ycnt - box_cy) : (box_cy - cut_to_in_ycnt);
assign cheb  = (abs_x >= abs_y) ? abs_x : abs_y;
assign dx_box = edge_s - {1'b0, cheb};
assign hash = cut_to_in_xcnt[7:0] ^ cut_to_in_ycnt[7:0] ^ {cut_to_in_ycnt[3:0], cut_to_in_xcnt[3:0]};

function automatic [8:0] soft_k;
    input signed [13:0] dx;
    input signed [13:0] band;
    input integer       sh;
    begin
        if(dx <= 0) begin
            soft_k = 9'd0;
        end
        else if(dx >= band) begin
            soft_k = 9'd256;
        end
        else begin
            soft_k = dx[7:0] << sh;
        end
    end
endfunction

assign k_pix = !cut_busy ? (release_prog ? 9'd256 : 9'd0) :
    (mode_latch == 3'd2) ? soft_k(dx_left_q,  BAND_SLIDE, 2) :
    (mode_latch == 3'd3) ? soft_k(dx_right_q, BAND_SLIDE, 2) :
    (mode_latch == 3'd4) ? (x_past_pic_q ? 9'd0 : soft_k(dx_blind_q, BAND_BLIND, 4)) :
    (mode_latch == 3'd5) ? (({1'b0, hash_q} < prog) ? 9'd256 : 9'd0) :
    (mode_latch == 3'd6) ? soft_k(dx_box_q, BAND_SLIDE, 2) :
                           prog;

assign coef1 = (cut_busy && (mode_latch == 3'd7)) ? ((fade_i <= half_frame) ? (9'd256 - black_level_q) : 9'd0) : (9'd256 - k_pix);
assign coef2 = (cut_busy && (mode_latch == 3'd7)) ? ((fade_i <= half_frame) ? 9'd0 : black_level_q) : k_pix;
assign cut_to_active = !cut_to_disable && (pchange_pending | cut_busy | release_prog);
assign cut_to_rd = cut_to_disable ? 2'd0 :
                   cut_busy ? 2'd2 :
                   release_prog ? 2'd1 : 2'd0;

wire    [16:0]                  prod_r1_c                   ;
wire    [16:0]                  prod_g1_c                   ;
wire    [16:0]                  prod_b1_c                   ;
wire    [16:0]                  prod_r2_c                   ;
wire    [16:0]                  prod_g2_c                   ;
wire    [16:0]                  prod_b2_c                   ;
reg     [16:0]                  prod_r1                     ;
reg     [16:0]                  prod_g1                     ;
reg     [16:0]                  prod_b1                     ;
reg     [16:0]                  prod_r2                     ;
reg     [16:0]                  prod_g2                     ;
reg     [16:0]                  prod_b2                     ;

dsp_mul_u8x9 U_MUL_R1(
    .CLK                        (clk                        ),
    .A                          (rgb1_d2[23:16]             ),
    .B                          (coef1_q                    ),
    .P                          (prod_r1_c                  )
);

dsp_mul_u8x9 U_MUL_G1(
    .CLK                        (clk                        ),
    .A                          (rgb1_d2[15:8]              ),
    .B                          (coef1_q                    ),
    .P                          (prod_g1_c                  )
);

dsp_mul_u8x9 U_MUL_B1(
    .CLK                        (clk                        ),
    .A                          (rgb1_d2[7:0]               ),
    .B                          (coef1_q                    ),
    .P                          (prod_b1_c                  )
);

dsp_mul_u8x9 U_MUL_R2(
    .CLK                        (clk                        ),
    .A                          (rgb2_d2[23:16]             ),
    .B                          (coef2_q                    ),
    .P                          (prod_r2_c                  )
);

dsp_mul_u8x9 U_MUL_G2(
    .CLK                        (clk                        ),
    .A                          (rgb2_d2[15:8]              ),
    .B                          (coef2_q                    ),
    .P                          (prod_g2_c                  )
);

dsp_mul_u8x9 U_MUL_B2(
    .CLK                        (clk                        ),
    .A                          (rgb2_d2[7:0]               ),
    .B                          (coef2_q                    ),
    .P                          (prod_b2_c                  )
);

always@(posedge clk) begin
    if(reset) begin
        prod_r1 <= 17'd0;
        prod_g1 <= 17'd0;
        prod_b1 <= 17'd0;
        prod_r2 <= 17'd0;
        prod_g2 <= 17'd0;
        prod_b2        <= 17'd0;
        span_q         <= 11'd0;
        coef1_q        <= 9'd0;
        coef2_q        <= 9'd0;
        rgb1_d         <= 24'd0;
        rgb2_d         <= 24'd0;
        rgb1_d2        <= 24'd0;
        rgb2_d2        <= 24'd0;
        dx_left_q      <= 14'd0;
        dx_right_q     <= 14'd0;
        dx_blind_q     <= 14'd0;
        dx_box_q       <= 14'd0;
        hash_q         <= 8'd0;
        x_past_pic_q   <= 1'b0;
    end
    else begin
        span_q        <= span_sel;
        coef1_q       <= coef1;
        coef2_q       <= coef2;
        rgb1_d        <= cut_to_in_rgb1;
        rgb2_d        <= cut_to_in_rgb2;
        rgb1_d2       <= rgb1_d;
        rgb2_d2       <= rgb2_d;
        dx_left_q     <= dx_left;
        dx_right_q    <= dx_right;
        dx_blind_q    <= dx_blind;
        dx_box_q      <= dx_box;
        hash_q        <= hash;
        x_past_pic_q  <= (cut_to_in_xcnt >= width_l);
        prod_r1 <= prod_r1_c;
        prod_g1 <= prod_g1_c;
        prod_b1 <= prod_b1_c;
        prod_r2 <= prod_r2_c;
        prod_g2 <= prod_g2_c;
        prod_b2 <= prod_b2_c;
    end
end

wire    [17:0]                  sum_r                       ;
wire    [17:0]                  sum_g                       ;
wire    [17:0]                  sum_b                       ;
assign sum_r = {1'b0, prod_r1} + {1'b0, prod_r2};
assign sum_g = {1'b0, prod_g1} + {1'b0, prod_g2};
assign sum_b = {1'b0, prod_b1} + {1'b0, prod_b2};

localparam                      PACK_W                      = 54;
wire    [PACK_W-1:0]            pack_in                     ;
reg     [PACK_W-1:0]            pack_dly [0:PIX_LAT-1]      ;
integer                         di                          ;
wire                            cut_dis_d                   ;
wire    [23:0]                  cut_rgb_d                   ;
wire    [12:0]                  cut_x_d                     ;
wire    [12:0]                  cut_y_d                     ;
wire                            cut_in_pic                  ;
wire    [23:0]                  cut_proc_rgb                ;

assign pack_in = {cut_to_disable, cut_to_in_rgb1,
                  cut_to_in_vsync, cut_to_in_hsync, cut_to_in_de,
                  cut_to_in_xcnt, cut_to_in_ycnt};

always@(posedge clk) begin
    if(reset) begin
        for(di = 0; di < PIX_LAT; di = di + 1) begin
            pack_dly[di] <= {PACK_W{1'b0}};
        end
    end
    else begin
        pack_dly[0] <= pack_in;
        for(di = 1; di < PIX_LAT; di = di + 1) begin
            pack_dly[di] <= pack_dly[di-1];
        end
    end
end

assign cut_dis_d    = pack_dly[PIX_LAT-1][53];
assign cut_rgb_d    = pack_dly[PIX_LAT-1][52:29];
assign cut_to_out_vsync = pack_dly[PIX_LAT-1][28];
assign cut_to_out_hsync = pack_dly[PIX_LAT-1][27];
assign cut_to_out_de    = pack_dly[PIX_LAT-1][26];
assign cut_to_out_xcnt  = pack_dly[PIX_LAT-1][25:13];
assign cut_to_out_ycnt  = pack_dly[PIX_LAT-1][12:0];
assign cut_x_d      = cut_to_out_xcnt;
assign cut_y_d      = cut_to_out_ycnt;
assign cut_in_pic   = (cut_x_d < cut_to_valid_width) &&
                      (cut_y_d >= 13'd1) &&
                      (cut_y_d <= cut_to_valid_height);
assign cut_proc_rgb = {sum_r[15:8], sum_g[15:8], sum_b[15:8]};
assign cut_to_out_rgb = cut_dis_d ? cut_rgb_d :
                        (cut_in_pic ? cut_proc_rgb : 24'h000000);

endmodule
