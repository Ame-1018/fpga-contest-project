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
// Create Date: 2026/10/19 19:50:00
// Design Name:
// Module Name: VPU_Scaler
// Project Name:
// Target Devices: EG4S20
// Tool Versions:
// Description: 只做水平缩放。输出高度等于输入有效高度，目标高度不参与比例。
//              输出的场同步、行同步、DE 和坐标是输入晚 9 拍，沿用原来的扫描。
//              源行要整行写完才能读，所以输入 ycnt==Y 显示的是源行 Y-2
//              （ycnt 从 1 起）。ycnt==1、超过有效高度的下一行，以及 xcnt
//              达到目标宽度之后，DE 仍在，像素为黑。480 行源图占用 ycnt 2..481，
//              320 行占用 2..321。三块行缓存按行号轮换，读的是上一行。
//              vpu_scaler_in_ready 在比例除法完成前为 0。水平权重取步进小数
//              的高 7 位。mul_scale_su 不寄存。
// Dependencies: tdp_scale_line, mul_scale_su
// Revision:
// Revision 0.02 - Horizontal only, follow input timing
// Additional Comments: 读地址打入后，沿用原来 s1..s4、sel 的间距采样行缓存。
//
//////////////////////////////////////////////////////////////////////////////////

module VPU_Scaler(
    input   wire                clk                         ,
    input   wire                reset                       ,

    input   wire                vpu_scaler_disable          ,
    input   wire    [12:0]      vpu_scaler_valid_width      ,
    input   wire    [12:0]      vpu_scaler_valid_height     ,
    input   wire    [12:0]      vpu_scaler_target_width     ,
    input   wire    [12:0]      vpu_scaler_target_height    ,

    input   wire                vpu_scaler_in_vsync         ,
    input   wire                vpu_scaler_in_hsync         ,
    input   wire                vpu_scaler_in_de            ,
    input   wire    [12:0]      vpu_scaler_in_xcnt          ,
    input   wire    [12:0]      vpu_scaler_in_ycnt          ,
    input   wire    [23:0]      vpu_scaler_in_rgb           ,

    output  wire                vpu_scaler_in_ready         ,

    output  reg                 vpu_scaler_out_vsync        ,
    output  reg                 vpu_scaler_out_hsync        ,
    output  reg                 vpu_scaler_out_de           ,
    output  reg     [12:0]      vpu_scaler_out_xcnt         ,
    output  reg     [12:0]      vpu_scaler_out_ycnt         ,
    output  reg     [23:0]      vpu_scaler_out_rgb
);

localparam                      S_IDLE                      = 2'd0;
localparam                      S_DIV                       = 2'd1;
localparam                      S_RUN                       = 2'd2;

reg             [1:0]           st                          ;
reg                             dis_run                     ;
reg                             vs_d                        ;
wire                            vs_pos                      ;

reg             [12:0]          src_w                       ;
reg             [12:0]          src_h                       ;
reg             [12:0]          dst_w                       ;

reg             [28:0]          x_step                      ;
reg             [31:0]          x_acc                       ;

reg             [4:0]           div_cnt                     ;
reg             [28:0]          div_dend                    ;
reg             [28:0]          div_quot                    ;
reg             [13:0]          div_rem                     ;
reg             [12:0]          div_sor                     ;

reg             [12:0]          wr_x                        ;
reg             [12:0]          wr_y                        ;
reg             [1:0]           wr_bank                     ;

reg                             s1_on, s2_on, s3_on, s4_on  ;
reg                             s1_by, s2_by, s3_by, s4_by  ;
reg                             s1_de, s2_de, s3_de, s4_de  ;
reg                             s1_vs, s2_vs, s3_vs, s4_vs  ;
reg                             s1_hs, s2_hs, s3_hs, s4_hs  ;
reg             [12:0]          s1_x, s2_x, s3_x, s4_x      ;
reg             [12:0]          s1_y, s2_y, s3_y, s4_y      ;
reg             [23:0]          s1_rgb, s2_rgb, s3_rgb, s4_rgb;
reg             [6:0]           s1_fx, s2_fx, s3_fx, s4_fx  ;
reg             [1:0]           s1_b, s2_b, s3_b, s4_b      ;

reg                             sel_on, sel_by, sel_de, sel_vs, sel_hs;
reg             [12:0]          sel_x, sel_y                ;
reg             [23:0]          sel_rgb                     ;
reg             [6:0]           sel_fx                      ;
reg             [23:0]          sel_a, sel_b                ;

reg                             hold_on, hold_by, hold_de, hold_vs, hold_hs;
reg             [12:0]          hold_x, hold_y              ;
reg             [23:0]          hold_rgb                    ;
reg             [7:0]           base_r, base_g, base_b      ;
reg signed      [16:0]          ph_r_q, ph_g_q, ph_b_q      ;

reg                             cap_on, cap_by, cap_de, cap_vs, cap_hs;
reg             [12:0]          cap_x, cap_y                ;
reg             [23:0]          cap_rgb                     ;
reg             [7:0]           h_r, h_g, h_b               ;

reg                             cap2_on, cap2_by, cap2_de, cap2_vs, cap2_hs;
reg             [12:0]          cap2_x, cap2_y              ;
reg             [23:0]          cap2_rgb                    ;
reg             [7:0]           h_r_d, h_g_d, h_b_d         ;

reg                             wr_we0, wr_we1, wr_we2      ;
reg             [10:0]          wr_ada                      ;
reg             [23:0]          wr_dia                      ;
reg             [10:0]          rd_a0, rd_b0                ;
reg             [10:0]          rd_a1, rd_b1                ;
reg             [10:0]          rd_a2, rd_b2                ;
reg             [23:0]          doa0_q, dob0_q              ;
reg             [23:0]          doa1_q, dob1_q              ;
reg             [23:0]          doa2_q, dob2_q              ;

wire            [13:0]          rem_sh                      ;
wire                            ge                          ;
wire            [28:0]          quot_n                      ;
wire            [31:0]          x_now                       ;
wire            [12:0]          x_int                       ;
wire            [12:0]          x_int1                      ;
wire            [6:0]           x_frac                      ;
wire            [12:0]          rd_line                     ;
wire            [1:0]           rd_bank                     ;
wire                            img_y                       ;
wire                            issue                       ;
wire                            pix_match                   ;
wire                            accept                      ;
wire            [12:0]          target_h_unused             ;

wire            [23:0]          doa0, dob0, doa1, dob1, doa2, dob2;
wire            [23:0]          row_a, row_b                ;
wire signed     [8:0]           d_r, d_g, d_b               ;
wire signed     [16:0]          p_r, p_g, p_b               ;

assign target_h_unused = vpu_scaler_target_height;
assign vs_pos  = vpu_scaler_in_vsync && !vs_d;
assign rem_sh  = {div_rem[12:0], div_dend[28]};
assign ge      = rem_sh >= {1'b0, div_sor};
assign quot_n  = {div_quot[27:0], ge};

assign x_now   = (vpu_scaler_in_de && (vpu_scaler_in_xcnt == 13'd0)) ? 32'd0 : x_acc;
assign x_int   = (x_now[28:16] >= src_w) ? (src_w - 13'd1) : x_now[28:16];
assign x_int1  = (x_int + 13'd1 >= src_w) ? (src_w - 13'd1) : (x_int + 13'd1);
assign x_frac  = x_now[15:9];
assign rd_line = vpu_scaler_in_ycnt - 13'd2;
assign rd_bank = mod3(rd_line);
assign img_y   = (vpu_scaler_in_ycnt >= 13'd2) &&
                 ({1'b0, vpu_scaler_in_ycnt} <= ({1'b0, src_h} + 14'd1));
assign issue   = !dis_run && (st == S_RUN) && vpu_scaler_in_de && img_y &&
                 (vpu_scaler_in_xcnt < dst_w);
assign pix_match = vpu_scaler_in_de &&
                   (vpu_scaler_in_xcnt == wr_x) &&
                   (vpu_scaler_in_ycnt == (wr_y + 13'd1));
assign accept  = !dis_run && (st == S_RUN) && pix_match && (wr_y < src_h);
assign vpu_scaler_in_ready = dis_run || (st == S_RUN);

function automatic [1:0] mod3;
    input [12:0] v;
    reg   [4:0]  s;
    begin
        s = {3'b0, v[1:0]} + {3'b0, v[3:2]} + {3'b0, v[5:4]} +
            {3'b0, v[7:6]} + {3'b0, v[9:8]} + {3'b0, v[11:10]} +
            {4'b0, v[12]};
        s = {3'b0, s[1:0]} + {3'b0, s[4:2]};
        if(s >= 5'd6)
            s = s - 5'd6;
        else if(s >= 5'd3)
            s = s - 5'd3;
        mod3 = s[1:0];
    end
endfunction

function automatic [12:0] clamp_w;
    input [12:0] v;
    begin
        if(v == 13'd0)
            clamp_w = 13'd0;
        else if(v > 13'd1280)
            clamp_w = 13'd1280;
        else
            clamp_w = v;
    end
endfunction

function automatic [12:0] clamp_h;
    input [12:0] v;
    begin
        if(v > 13'd720)
            clamp_h = 13'd720;
        else
            clamp_h = v;
    end
endfunction

function automatic [7:0] sat8;
    input signed [10:0] v;
    begin
        if(v < 0)
            sat8 = 8'd0;
        else if(v > 11'sd255)
            sat8 = 8'd255;
        else
            sat8 = v[7:0];
    end
endfunction

function automatic signed [10:0] lerp_sh;
    input [7:0]         a;
    input signed [16:0] prod;
    reg signed [17:0]   sum;
    begin
        sum     = $signed({3'b0, a, 7'b0}) + $signed({{1{prod[16]}}, prod});
        lerp_sh = sum >>> 7;
    end
endfunction

assign row_a = (s4_b == 2'd0) ? doa0_q : (s4_b == 2'd1) ? doa1_q : doa2_q;
assign row_b = (s4_b == 2'd0) ? dob0_q : (s4_b == 2'd1) ? dob1_q : dob2_q;
assign d_r = $signed({1'b0, sel_b[23:16]}) - $signed({1'b0, sel_a[23:16]});
assign d_g = $signed({1'b0, sel_b[15:8]})  - $signed({1'b0, sel_a[15:8]});
assign d_b = $signed({1'b0, sel_b[7:0]})   - $signed({1'b0, sel_a[7:0]});

mul_scale_su U_H_R(.CLK(clk), .A(d_r), .B({1'b0, sel_fx}), .P(p_r));
mul_scale_su U_H_G(.CLK(clk), .A(d_g), .B({1'b0, sel_fx}), .P(p_g));
mul_scale_su U_H_B(.CLK(clk), .A(d_b), .B({1'b0, sel_fx}), .P(p_b));

tdp_scale_line U_LINE0(
    .doa(doa0), .dia(wr_dia), .addra(wr_we0 ? wr_ada : rd_a0),
    .clka(clk), .wea(wr_we0), .rsta(reset),
    .dob(dob0), .dib(24'd0), .addrb(rd_b0), .clkb(clk), .web(1'b0), .rstb(reset)
);
tdp_scale_line U_LINE1(
    .doa(doa1), .dia(wr_dia), .addra(wr_we1 ? wr_ada : rd_a1),
    .clka(clk), .wea(wr_we1), .rsta(reset),
    .dob(dob1), .dib(24'd0), .addrb(rd_b1), .clkb(clk), .web(1'b0), .rstb(reset)
);
tdp_scale_line U_LINE2(
    .doa(doa2), .dia(wr_dia), .addra(wr_we2 ? wr_ada : rd_a2),
    .clka(clk), .wea(wr_we2), .rsta(reset),
    .dob(dob2), .dib(24'd0), .addrb(rd_b2), .clkb(clk), .web(1'b0), .rstb(reset)
);

always@(posedge clk) begin
    if(reset) begin
        st       <= S_IDLE;
        dis_run  <= 1'b1;
        vs_d     <= 1'b0;
        src_w    <= 13'd1;
        src_h    <= 13'd1;
        dst_w    <= 13'd1;
        x_step   <= 29'd0;
        x_acc    <= 32'd0;
        div_cnt  <= 5'd0;
        div_dend <= 29'd0;
        div_quot <= 29'd0;
        div_rem  <= 14'd0;
        div_sor  <= 13'd1;
        wr_x     <= 13'd0;
        wr_y     <= 13'd0;
        wr_bank  <= 2'd0;
        s1_on <= 1'b0; s2_on <= 1'b0; s3_on <= 1'b0; s4_on <= 1'b0;
        s1_by <= 1'b1; s2_by <= 1'b1; s3_by <= 1'b1; s4_by <= 1'b1;
        s1_de <= 1'b0; s2_de <= 1'b0; s3_de <= 1'b0; s4_de <= 1'b0;
        s1_vs <= 1'b0; s2_vs <= 1'b0; s3_vs <= 1'b0; s4_vs <= 1'b0;
        s1_hs <= 1'b0; s2_hs <= 1'b0; s3_hs <= 1'b0; s4_hs <= 1'b0;
        s1_x <= 13'd0; s2_x <= 13'd0; s3_x <= 13'd0; s4_x <= 13'd0;
        s1_y <= 13'd0; s2_y <= 13'd0; s3_y <= 13'd0; s4_y <= 13'd0;
        s1_rgb <= 24'd0; s2_rgb <= 24'd0; s3_rgb <= 24'd0; s4_rgb <= 24'd0;
        s1_fx <= 7'd0; s2_fx <= 7'd0; s3_fx <= 7'd0; s4_fx <= 7'd0;
        s1_b <= 2'd0; s2_b <= 2'd0; s3_b <= 2'd0; s4_b <= 2'd0;
        sel_on <= 1'b0; sel_by <= 1'b1; sel_de <= 1'b0; sel_vs <= 1'b0; sel_hs <= 1'b0;
        sel_x <= 13'd0; sel_y <= 13'd0; sel_rgb <= 24'd0; sel_fx <= 7'd0;
        sel_a <= 24'd0; sel_b <= 24'd0;
        hold_on <= 1'b0; hold_by <= 1'b1; hold_de <= 1'b0; hold_vs <= 1'b0; hold_hs <= 1'b0;
        hold_x <= 13'd0; hold_y <= 13'd0; hold_rgb <= 24'd0;
        base_r <= 8'd0; base_g <= 8'd0; base_b <= 8'd0;
        ph_r_q <= 17'd0; ph_g_q <= 17'd0; ph_b_q <= 17'd0;
        cap_on <= 1'b0; cap_by <= 1'b1; cap_de <= 1'b0; cap_vs <= 1'b0; cap_hs <= 1'b0;
        cap_x <= 13'd0; cap_y <= 13'd0; cap_rgb <= 24'd0;
        h_r <= 8'd0; h_g <= 8'd0; h_b <= 8'd0;
        cap2_on <= 1'b0; cap2_by <= 1'b1; cap2_de <= 1'b0; cap2_vs <= 1'b0; cap2_hs <= 1'b0;
        cap2_x <= 13'd0; cap2_y <= 13'd0; cap2_rgb <= 24'd0;
        h_r_d <= 8'd0; h_g_d <= 8'd0; h_b_d <= 8'd0;
        wr_we0 <= 1'b0; wr_we1 <= 1'b0; wr_we2 <= 1'b0;
        wr_ada <= 11'd0; wr_dia <= 24'd0;
        rd_a0 <= 11'd0; rd_b0 <= 11'd0;
        rd_a1 <= 11'd0; rd_b1 <= 11'd0;
        rd_a2 <= 11'd0; rd_b2 <= 11'd0;
        doa0_q <= 24'd0; dob0_q <= 24'd0;
        doa1_q <= 24'd0; dob1_q <= 24'd0;
        doa2_q <= 24'd0; dob2_q <= 24'd0;
        vpu_scaler_out_vsync <= 1'b0;
        vpu_scaler_out_hsync <= 1'b0;
        vpu_scaler_out_de    <= 1'b0;
        vpu_scaler_out_xcnt  <= 13'd0;
        vpu_scaler_out_ycnt  <= 13'd0;
        vpu_scaler_out_rgb   <= 24'd0;
    end
    else begin
        vs_d <= vpu_scaler_in_vsync;

        if(vs_pos) begin
            src_w   <= clamp_w(vpu_scaler_valid_width);
            src_h   <= clamp_h(vpu_scaler_valid_height);
            dst_w   <= clamp_w(vpu_scaler_target_width);
            wr_x    <= 13'd0;
            wr_y    <= 13'd0;
            wr_bank <= 2'd0;
            x_acc   <= 32'd0;
            if(vpu_scaler_disable ||
               (vpu_scaler_valid_width == 13'd0) ||
               (vpu_scaler_valid_height == 13'd0) ||
               (vpu_scaler_target_width == 13'd0)) begin
                dis_run <= 1'b1;
                st      <= S_IDLE;
            end
            else begin
                dis_run  <= 1'b0;
                st       <= S_DIV;
                div_cnt  <= 5'd0;
                div_rem  <= 14'd0;
                div_quot <= 29'd0;
                div_dend <= {clamp_w(vpu_scaler_valid_width), 16'b0};
                div_sor  <= clamp_w(vpu_scaler_target_width);
            end
        end
        else if(!dis_run && (st == S_DIV)) begin
            if(div_cnt == 5'd28) begin
                x_step <= quot_n;
                st     <= S_RUN;
            end
            else begin
                div_rem  <= ge ? (rem_sh - {1'b0, div_sor}) : rem_sh;
                div_quot <= quot_n;
                div_dend <= {div_dend[27:0], 1'b0};
                div_cnt  <= div_cnt + 5'd1;
            end
        end

        if(issue && !vs_pos) begin
            if(rd_bank == 2'd0) begin
                rd_a0 <= x_int[10:0];
                rd_b0 <= x_int1[10:0];
            end
            if(rd_bank == 2'd1) begin
                rd_a1 <= x_int[10:0];
                rd_b1 <= x_int1[10:0];
            end
            if(rd_bank == 2'd2) begin
                rd_a2 <= x_int[10:0];
                rd_b2 <= x_int1[10:0];
            end
            x_acc <= x_now + {3'b0, x_step};
        end
        else if(vpu_scaler_in_de && (vpu_scaler_in_xcnt == 13'd0))
            x_acc <= 32'd0;

        wr_we0 <= !vs_pos && accept && (wr_bank == 2'd0);
        wr_we1 <= !vs_pos && accept && (wr_bank == 2'd1);
        wr_we2 <= !vs_pos && accept && (wr_bank == 2'd2);
        wr_ada <= wr_x[10:0];
        wr_dia <= vpu_scaler_in_rgb;

        if(accept && !vs_pos) begin
            if(wr_x == src_w - 13'd1) begin
                wr_x    <= 13'd0;
                wr_y    <= wr_y + 13'd1;
                wr_bank <= (wr_bank == 2'd2) ? 2'd0 : (wr_bank + 2'd1);
            end
            else
                wr_x <= wr_x + 13'd1;
        end

        s1_on  <= issue && !vs_pos;
        s1_by  <= dis_run;
        s1_de  <= vpu_scaler_in_de;
        s1_vs  <= vpu_scaler_in_vsync;
        s1_hs  <= vpu_scaler_in_hsync;
        s1_x   <= vpu_scaler_in_xcnt;
        s1_y   <= vpu_scaler_in_ycnt;
        s1_rgb <= vpu_scaler_in_rgb;
        s1_fx  <= x_frac;
        s1_b   <= rd_bank;

        s2_on <= s1_on; s2_by <= s1_by; s2_de <= s1_de; s2_vs <= s1_vs; s2_hs <= s1_hs;
        s2_x <= s1_x; s2_y <= s1_y; s2_rgb <= s1_rgb; s2_fx <= s1_fx; s2_b <= s1_b;

        s3_on <= s2_on; s3_by <= s2_by; s3_de <= s2_de; s3_vs <= s2_vs; s3_hs <= s2_hs;
        s3_x <= s2_x; s3_y <= s2_y; s3_rgb <= s2_rgb; s3_fx <= s2_fx; s3_b <= s2_b;

        s4_on <= s3_on; s4_by <= s3_by; s4_de <= s3_de; s4_vs <= s3_vs; s4_hs <= s3_hs;
        s4_x <= s3_x; s4_y <= s3_y; s4_rgb <= s3_rgb; s4_fx <= s3_fx; s4_b <= s3_b;

        doa0_q <= doa0; dob0_q <= dob0;
        doa1_q <= doa1; dob1_q <= dob1;
        doa2_q <= doa2; dob2_q <= dob2;

        sel_a   <= row_a;
        sel_b   <= row_b;
        sel_fx  <= s4_fx;
        sel_on  <= s4_on;
        sel_by  <= s4_by;
        sel_de  <= s4_de;
        sel_vs  <= s4_vs;
        sel_hs  <= s4_hs;
        sel_x   <= s4_x;
        sel_y   <= s4_y;
        sel_rgb <= s4_rgb;

        ph_r_q <= p_r; ph_g_q <= p_g; ph_b_q <= p_b;
        base_r <= sel_a[23:16]; base_g <= sel_a[15:8]; base_b <= sel_a[7:0];
        hold_on <= sel_on; hold_by <= sel_by; hold_de <= sel_de;
        hold_vs <= sel_vs; hold_hs <= sel_hs;
        hold_x <= sel_x; hold_y <= sel_y; hold_rgb <= sel_rgb;

        cap_on <= hold_on; cap_by <= hold_by; cap_de <= hold_de;
        cap_vs <= hold_vs; cap_hs <= hold_hs;
        cap_x <= hold_x; cap_y <= hold_y; cap_rgb <= hold_rgb;
        if(hold_on) begin
            h_r <= sat8(lerp_sh(base_r, ph_r_q));
            h_g <= sat8(lerp_sh(base_g, ph_g_q));
            h_b <= sat8(lerp_sh(base_b, ph_b_q));
        end

        cap2_on <= cap_on; cap2_by <= cap_by; cap2_de <= cap_de;
        cap2_vs <= cap_vs; cap2_hs <= cap_hs;
        cap2_x <= cap_x; cap2_y <= cap_y; cap2_rgb <= cap_rgb;
        h_r_d <= h_r; h_g_d <= h_g; h_b_d <= h_b;

        vpu_scaler_out_vsync <= cap2_vs;
        vpu_scaler_out_hsync <= cap2_hs;
        vpu_scaler_out_de    <= cap2_de;
        vpu_scaler_out_xcnt  <= cap2_x;
        vpu_scaler_out_ycnt  <= cap2_y;
        if(cap2_by)
            vpu_scaler_out_rgb <= cap2_rgb;
        else if(cap2_on)
            vpu_scaler_out_rgb <= {h_r_d, h_g_d, h_b_d};
        else
            vpu_scaler_out_rgb <= 24'd0;
    end
end

endmodule
