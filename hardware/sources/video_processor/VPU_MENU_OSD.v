`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: VPU_MENU_OSD
// Description: 拨码 2 打开时在画面中央叠一块深色菜单。
//              行名和数值都是 16x32 中文或数字，字模在 osd_infor_rom。
//              这块 ROM 原是右上角信息条用的，现在整块交给菜单。
//              偶数编号在 32 bit 的高 16 位，bit31 和 bit15 是左像素。
//              标题右侧是按键或串口。音频页标题后面固定写波形。
//              风格值写成原图、灰度、二值、反色。颜色写成默认或彩虹。
//              参数行右侧始终是当前值。返回行未选中写「返回」，选中写「确认」，
//              选中时这一行底色更深、文字更亮。
//              开关仍直接显示开或关。读 ROM 晚 1 拍，视频同步一起晚 3 拍。
//////////////////////////////////////////////////////////////////////////////////

module VPU_MENU_OSD #(
    parameter                   INFOR_INIT_FILE             = "../sources/osd/osd_infor_init.mem"
)(
    input   wire                clk                             ,
    input   wire                reset                           ,

    input   wire                menu_on                         ,
    input   wire                menu_uart                       ,
    input   wire    [2:0]       menu_page                       ,
    input   wire    [3:0]       menu_item                       ,
    input   wire                menu_edit                       ,

    input   wire                cut_disable                     ,
    input   wire    [2:0]       cut_mode                        ,
    input   wire    [1:0]       cut_speed                       ,
    input   wire                color_disable                   ,
    input   wire    [7:0]       lumi                            ,
    input   wire    [7:0]       contrast                        ,
    input   wire    [7:0]       temp                            ,
    input   wire    [7:0]       tint                            ,
    input   wire                style_disable                   ,
    input   wire    [2:0]       style_mode                      ,
    input   wire    [7:0]       style_th                        ,
    input   wire    [7:0]       style_gamma                     ,
    input   wire                osd_disable                     ,
    input   wire    [12:0]      logo_x                          ,
    input   wire    [12:0]      logo_y                          ,
    input   wire                txt_disable                     ,
    input   wire    [12:0]      txt_x                           ,
    input   wire    [12:0]      txt_y                           ,
    input   wire    [12:0]      txt_w                           ,
    input   wire    [1:0]       txt_speed                       ,
    input   wire    [1:0]       txt_cmode                       ,
    input   wire    [23:0]      txt_color                       ,
    input   wire                aud_disable                     ,
    input   wire    [1:0]       aud_mode                        ,
    input   wire    [1:0]       aud_cmode                       ,
    input   wire    [23:0]      aud_color                       ,
    input   wire    [12:0]      aud_x                           ,
    input   wire    [12:0]      aud_y                           ,
    input   wire                scale_disable                   ,
    input   wire    [12:0]      scale_w                         ,
    input   wire    [12:0]      scale_h                         ,

    input   wire                in_vsync                        ,
    input   wire                in_hsync                        ,
    input   wire                in_de                           ,
    input   wire    [12:0]      in_x                            ,
    input   wire    [12:0]      in_y                            ,
    input   wire    [23:0]      in_rgb                          ,

    output  reg                 out_vsync                       ,
    output  reg                 out_hsync                       ,
    output  reg                 out_de                          ,
    output  reg     [12:0]      out_x                           ,
    output  reg     [12:0]      out_y                           ,
    output  reg     [23:0]      out_rgb
);

localparam integer              X0                          = 416;
localparam integer              Y0                          = 184;
localparam integer              PW                          = 448;
localparam integer              PH                          = 352;
localparam integer              HEADER                      = 64;
localparam integer              ROW_H                       = 36;
localparam integer              PAD                         = 32;
localparam integer              TEXT_W                      = 384;
localparam [5:0]                DIG0                        = 6'd49;
localparam [5:0]                G_BLANK                     = 6'd63;
localparam [5:0]                G_QUE                       = 6'd59;
localparam [5:0]                G_REN                       = 6'd60;

localparam [23:0]               C_TEXT                      = 24'hF5F5F7;
localparam [23:0]               C_DIM                       = 24'hA1A1A6;
localparam [23:0]               C_BLUE                      = 24'h0A84FF;
localparam [23:0]               C_BAR                       = 24'h2C2C2E;
localparam [23:0]               C_HEAVY                     = 24'h121214;
localparam [23:0]               C_HEAVY_INK                 = 24'hFFFFFF;

reg     [15:0]                  bcd         [0:34]              ;
reg     [5:0]                   scan                            ;
integer                         bi                              ;

reg                             s_vs, s_hs, s_de                ;
reg     [12:0]                  s_x, s_y                        ;
reg     [23:0]                  s_rgb                           ;
reg                             s_panel, s_bar, s_heavy, s_accent;
reg                             s_hit                           ;
reg     [9:0]                   s_addr                          ;
reg     [4:0]                   s_bit                           ;
reg     [23:0]                  s_ink                           ;

reg                             m_vs, m_hs, m_de                ;
reg     [12:0]                  m_x, m_y                        ;
reg     [23:0]                  m_rgb                           ;
reg                             m_panel, m_bar, m_heavy, m_accent;
reg                             m_hit                           ;
reg     [4:0]                   m_bit                           ;
reg     [23:0]                  m_ink                           ;

reg                             d_vs, d_hs, d_de                ;
reg     [12:0]                  d_x, d_y                        ;
reg     [23:0]                  d_rgb                           ;
reg                             d_panel, d_bar, d_heavy, d_accent;
reg                             d_hit                           ;
reg     [4:0]                   d_bit                           ;
reg     [23:0]                  d_ink                           ;
reg     [31:0]                  d_word                          ;

`ifdef MENU_SIM
reg     [31:0]                  imem        [0:1023]            ;
reg     [31:0]                  rom_raw                         ;
initial $readmemh(INFOR_INIT_FILE, imem);
`else
wire    [31:0]                  rom_raw                         ;
`endif

function [7:0] dim8;
    input [7:0] c;
    begin
        dim8 = (c >> 2) + (c >> 3) + 8'h18;
    end
endfunction

function [3:0] n_of;
    input [2:0] page;
    begin
        case(page)
            3'd0: n_of = 4'd4;
            3'd1: n_of = 4'd6;
            3'd2: n_of = 4'd4;
            3'd3: n_of = 4'd4;
            3'd4: n_of = 4'd7;
            3'd5: n_of = 4'd5;
            default: n_of = 4'd4;
        endcase
    end
endfunction

function [3:0] win_of;
    input [3:0] item;
    input [3:0] n;
    reg   [3:0] w;
    begin
        w = 4'd0;
        if((n > 4'd8) && (item > 4'd3))
            w = item - 4'd3;
        if((n > 4'd8) && ((w + 4'd8) > n))
            w = n - 4'd8;
        win_of = w;
    end
endfunction

function [3:0] row_of;
    input [12:0] yrel;
    begin
        if(yrel < 13'd36)       row_of = 4'd0;
        else if(yrel < 13'd72)  row_of = 4'd1;
        else if(yrel < 13'd108) row_of = 4'd2;
        else if(yrel < 13'd144) row_of = 4'd3;
        else if(yrel < 13'd180) row_of = 4'd4;
        else if(yrel < 13'd216) row_of = 4'd5;
        else if(yrel < 13'd252) row_of = 4'd6;
        else if(yrel < 13'd288) row_of = 4'd7;
        else                    row_of = 4'd15;
    end
endfunction

function [15:0] to_bcd;
    input [12:0] bin;
    integer i;
    reg [28:0] sh;
    begin
        sh = {16'd0, bin};
        for(i = 0; i < 13; i = i + 1) begin
            if(sh[16:13] >= 5) sh[16:13] = sh[16:13] + 4'd3;
            if(sh[20:17] >= 5) sh[20:17] = sh[20:17] + 4'd3;
            if(sh[24:21] >= 5) sh[24:21] = sh[24:21] + 4'd3;
            if(sh[28:25] >= 5) sh[28:25] = sh[28:25] + 4'd3;
            sh = sh << 1;
        end
        to_bcd = sh[28:13];
    end
endfunction

function [12:0] field_val;
    input [5:0] id;
    begin
        case(id)
            6'd1:  field_val = {10'd0, cut_mode};
            6'd2:  field_val = {11'd0, cut_speed};
            6'd4:  field_val = {5'd0, lumi};
            6'd5:  field_val = {5'd0, contrast};
            6'd6:  field_val = {5'd0, temp};
            6'd7:  field_val = {5'd0, tint};
            6'd9:  field_val = {10'd0, (style_mode <= 3'd3) ? style_mode : 3'd0};
            6'd10: field_val = {5'd0, style_th};
            6'd11: field_val = {5'd0, style_gamma};
            6'd13: field_val = logo_x;
            6'd14: field_val = logo_y;
            6'd16: field_val = txt_x;
            6'd17: field_val = txt_y;
            6'd18: field_val = txt_w;
            6'd19: field_val = {11'd0, txt_speed};
            6'd20: field_val = (txt_cmode == 2'd1) ? 13'd1 : 13'd0;
            6'd21: field_val = {5'd0, txt_color[23:16]};
            6'd22: field_val = {5'd0, txt_color[15:8]};
            6'd23: field_val = {5'd0, txt_color[7:0]};
            6'd25: field_val = {11'd0, aud_mode};
            6'd26: field_val = (aud_cmode == 2'd1) ? 13'd1 : 13'd0;
            6'd27: field_val = {5'd0, aud_color[23:16]};
            6'd28: field_val = {5'd0, aud_color[15:8]};
            6'd29: field_val = {5'd0, aud_color[7:0]};
            6'd30: field_val = aud_x;
            6'd31: field_val = aud_y;
            6'd33: field_val = scale_w;
            6'd34: field_val = scale_h;
            default: field_val = 13'd0;
        endcase
    end
endfunction

function [5:0] item_field;
    input [2:0] page;
    input [3:0] item;
    begin
        case({page, item})
            {3'd0, 4'd2}: item_field = 6'd1;
            {3'd0, 4'd3}: item_field = 6'd2;
            {3'd1, 4'd2}: item_field = 6'd4;
            {3'd1, 4'd3}: item_field = 6'd5;
            {3'd1, 4'd4}: item_field = 6'd6;
            {3'd1, 4'd5}: item_field = 6'd7;
            {3'd2, 4'd2}: item_field = 6'd9;
            {3'd2, 4'd3}: item_field = 6'd10;
            {3'd3, 4'd2}: item_field = 6'd13;
            {3'd3, 4'd3}: item_field = 6'd14;
            {3'd4, 4'd2}: item_field = 6'd16;
            {3'd4, 4'd3}: item_field = 6'd17;
            {3'd4, 4'd4}: item_field = 6'd18;
            {3'd4, 4'd5}: item_field = 6'd19;
            {3'd4, 4'd6}: item_field = 6'd20;
            {3'd5, 4'd2}: item_field = 6'd26;
            {3'd5, 4'd3}: item_field = 6'd30;
            {3'd5, 4'd4}: item_field = 6'd31;
            {3'd6, 4'd2}: item_field = 6'd33;
            {3'd6, 4'd3}: item_field = 6'd34;
            default: item_field = 6'd63;
        endcase
    end
endfunction

function switch_on;
    input [2:0] page;
    begin
        case(page)
            3'd0: switch_on = ~cut_disable;
            3'd1: switch_on = ~color_disable;
            3'd2: switch_on = ~style_disable;
            3'd3: switch_on = ~osd_disable;
            3'd4: switch_on = ~txt_disable;
            3'd5: switch_on = ~aud_disable;
            default: switch_on = ~scale_disable;
        endcase
    end
endfunction

function [5:0] two_at;
    input [5:0] a;
    input [5:0] b;
    input [4:0] col;
    begin
        if(col == 5'd0)      two_at = a;
        else if(col == 5'd1) two_at = b;
        else                 two_at = G_BLANK;
    end
endfunction

function [5:0] title_gid;
    input [2:0] page;
    input [4:0] col;
    begin
        case(page)
            3'd0: title_gid = two_at(6'd4,  6'd5,  col);
            3'd1: title_gid = two_at(6'd10, 6'd11, col);
            3'd2: title_gid = two_at(6'd17, 6'd18, col);
            3'd3: title_gid = two_at(6'd26, 6'd27, col);
            3'd4: title_gid = two_at(6'd31, 6'd32, col);
            3'd5: begin
                if(col == 5'd2)      title_gid = 6'd37;
                else if(col == 5'd3) title_gid = 6'd38;
                else                 title_gid = two_at(6'd35, 6'd36, col);
            end
            default: title_gid = two_at(6'd42, 6'd43, col);
        endcase
    end
endfunction

function [5:0] name_gid;
    input [2:0] page;
    input [3:0] item;
    input [4:0] col;
    input       back_ok;
    begin
        if(item == 4'd0)
            name_gid = back_ok ? two_at(G_QUE, G_REN, col) : two_at(6'd0, 6'd1, col);
        else if(item == 4'd1)
            name_gid = two_at(6'd2, 6'd3, col);
        else begin
            case(page)
                3'd0: name_gid = (item == 4'd2) ? two_at(6'd6, 6'd7, col) :
                                 two_at(6'd8, 6'd9, col);
                3'd1: name_gid = (item == 4'd2) ? two_at(6'd12, 6'd9, col) :
                                 (item == 4'd3) ? two_at(6'd13, 6'd14, col) :
                                 (item == 4'd4) ? two_at(6'd10, 6'd15, col) :
                                 two_at(6'd10, 6'd16, col);
                3'd2: name_gid = (item == 4'd2) ? two_at(6'd6, 6'd7, col) :
                                 two_at(6'd19, 6'd20, col);
                3'd3: name_gid = (item == 4'd2) ? two_at(6'd28, 6'd29, col) :
                                 two_at(6'd30, 6'd29, col);
                3'd4: name_gid = (item == 4'd2) ? two_at(6'd28, 6'd29, col) :
                                 (item == 4'd3) ? two_at(6'd30, 6'd29, col) :
                                 (item == 4'd4) ? two_at(6'd33, 6'd9, col) :
                                 (item == 4'd5) ? two_at(6'd8, 6'd9, col) :
                                 two_at(6'd34, 6'd10, col);
                3'd5: name_gid = (item == 4'd2) ? two_at(6'd34, 6'd10, col) :
                                 (item == 4'd3) ? two_at(6'd28, 6'd29, col) :
                                 two_at(6'd30, 6'd29, col);
                default: name_gid = (item == 4'd2) ? two_at(6'd33, 6'd9, col) :
                                     two_at(6'd44, 6'd9, col);
            endcase
        end
    end
endfunction

function [5:0] word_gid;
    input [5:0] a;
    input [5:0] b;
    input [4:0] col;
    begin
        if(col == 5'd16)      word_gid = a;
        else if(col == 5'd17) word_gid = b;
        else                  word_gid = G_BLANK;
    end
endfunction

function [5:0] dig_gid;
    input [15:0] bv;
    input [4:0]  col;
    reg   [3:0]  d3, d2, d1, d0;
    begin
        d3 = bv[15:12];
        d2 = bv[11:8];
        d1 = bv[7:4];
        d0 = bv[3:0];
        if(col == 5'd16)
            dig_gid = (d3 == 4'd0) ? G_BLANK : (DIG0 + {2'b0, d3});
        else if(col == 5'd17)
            dig_gid = ((d3 == 4'd0) && (d2 == 4'd0)) ? G_BLANK : (DIG0 + {2'b0, d2});
        else if(col == 5'd18)
            dig_gid = ((d3 == 4'd0) && (d2 == 4'd0) && (d1 == 4'd0)) ? G_BLANK :
                      (DIG0 + {2'b0, d1});
        else if(col == 5'd19)
            dig_gid = DIG0 + {2'b0, d0};
        else
            dig_gid = G_BLANK;
    end
endfunction

function [5:0] cell_gid;
    input        header;
    input [2:0]  page;
    input [3:0]  item;
    input [4:0]  col;
    input [2:0]  style_show;
    input        back_ok;
    reg   [5:0]  fid;
    reg   [1:0]  cm;
    begin
        cell_gid = G_BLANK;
        if(header) begin
            if(col == 5'd20)
                cell_gid = menu_uart ? 6'd47 : 6'd45;
            else if(col == 5'd21)
                cell_gid = menu_uart ? 6'd48 : 6'd46;
            else
                cell_gid = title_gid(page, col);
        end
        else if(col < 5'd8) begin
            cell_gid = name_gid(page, item, col, back_ok);
        end
        else if(item == 4'd1) begin
            cell_gid = (col == 5'd16) ? (switch_on(page) ? 6'd2 : 6'd3) : G_BLANK;
        end
        else if((page == 3'd2) && (item == 4'd2)) begin
            case(style_show)
                3'd1:    cell_gid = word_gid(6'd23, 6'd9,  col);
                3'd2:    cell_gid = word_gid(6'd24, 6'd20, col);
                3'd3:    cell_gid = word_gid(6'd25, 6'd10, col);
                default: cell_gid = word_gid(6'd21, 6'd22, col);
            endcase
        end
        else if(((page == 3'd4) && (item == 4'd6)) ||
                ((page == 3'd5) && (item == 4'd2))) begin
            cm = (page == 3'd4) ? txt_cmode : aud_cmode;
            cell_gid = (cm == 2'd1) ? word_gid(6'd11, 6'd41, col) :
                       word_gid(6'd39, 6'd40, col);
        end
        else begin
            fid = item_field(page, item);
            if(fid != 6'd63)
                cell_gid = dig_gid(bcd[fid], col);
        end
    end
endfunction

always @(posedge clk) begin
    if(reset) begin
        scan <= 6'd0;
        for(bi = 0; bi < 35; bi = bi + 1)
            bcd[bi] <= 16'd0;
    end
    else begin
        if(scan <= 6'd34)
            bcd[scan] <= to_bcd(field_val(scan));
        scan <= (scan == 6'd34) ? 6'd0 : (scan + 6'd1);
    end
end

always @(posedge clk) begin
    if(reset) begin
        s_vs <= 1'b0; s_hs <= 1'b0; s_de <= 1'b0;
        s_x <= 13'd0; s_y <= 13'd0; s_rgb <= 24'd0;
        s_panel <= 1'b0; s_bar <= 1'b0; s_heavy <= 1'b0; s_accent <= 1'b0;
        s_hit <= 1'b0; s_addr <= 10'd0; s_bit <= 5'd0; s_ink <= C_TEXT;
        m_vs <= 1'b0; m_hs <= 1'b0; m_de <= 1'b0;
        m_x <= 13'd0; m_y <= 13'd0; m_rgb <= 24'd0;
        m_panel <= 1'b0; m_bar <= 1'b0; m_heavy <= 1'b0; m_accent <= 1'b0;
        m_hit <= 1'b0; m_bit <= 5'd0; m_ink <= C_TEXT;
        d_vs <= 1'b0; d_hs <= 1'b0; d_de <= 1'b0;
        d_x <= 13'd0; d_y <= 13'd0; d_rgb <= 24'd0;
        d_panel <= 1'b0; d_bar <= 1'b0; d_heavy <= 1'b0; d_accent <= 1'b0;
        d_hit <= 1'b0; d_bit <= 5'd0; d_ink <= C_TEXT; d_word <= 32'd0;
        out_vsync <= 1'b0; out_hsync <= 1'b0; out_de <= 1'b0;
        out_x <= 13'd0; out_y <= 13'd0; out_rgb <= 24'd0;
    end
    else begin
        begin : pick
            reg [12:0] xrel, yrel, yin;
            reg [4:0]  col;
            reg [3:0]  row, nitem, w0, abs_item;
            reg [5:0]  gid;
            reg [2:0]  style_show;
            reg        header, in_panel, in_bar, valid_item, selected, in_glyph;
            xrel = 13'd0;
            yrel = 13'd0;
            yin  = 13'd0;
            col  = 5'd0;
            row  = 4'd0;
            gid  = G_BLANK;
            nitem = n_of(menu_page);
            w0 = win_of(menu_item, nitem);
            header = 1'b0;
            in_panel = menu_on && (in_x >= X0) && (in_x < (X0 + PW)) &&
                       (in_y >= Y0) && (in_y < (Y0 + PH));
            in_bar = 1'b0;
            valid_item = 1'b0;
            selected = 1'b0;
            in_glyph = 1'b0;
            style_show = (style_mode <= 3'd3) ? style_mode : 3'd0;
            if(in_panel && (in_y < (Y0 + HEADER))) begin
                header = 1'b1;
                xrel = in_x - (X0 + PAD);
                yin  = in_y - (Y0 + 16);
                if((xrel < TEXT_W) && (yin < 13'd32)) begin
                    col = xrel[8:4];
                    gid = cell_gid(1'b1, menu_page, 4'd0, col, style_show, 1'b0);
                    in_glyph = (gid != G_BLANK);
                end
            end
            else if(in_panel) begin
                yrel = in_y - (Y0 + HEADER);
                row  = row_of(yrel);
                abs_item = w0 + row;
                valid_item = (row != 4'd15) && (abs_item < nitem);
                selected = valid_item && (abs_item == menu_item);
                in_bar = selected;
                xrel = in_x - (X0 + PAD);
                yin  = yrel - (row * ROW_H);
                if(valid_item && (xrel < TEXT_W) && (yin < 13'd32)) begin
                    col = xrel[8:4];
                    gid = cell_gid(1'b0, menu_page, abs_item, col, style_show,
                                   selected && (abs_item == 4'd0));
                    in_glyph = (gid != G_BLANK);
                end
            end
            s_hit  <= in_glyph;
            s_addr <= in_glyph ? {gid[5:1], yin[4:0]} : 10'd0;
            s_bit  <= gid[0] ? (5'd15 - {1'b0, xrel[3:0]}) : (5'd31 - {1'b0, xrel[3:0]});
            s_vs <= in_vsync;
            s_hs <= in_hsync;
            s_de <= in_de;
            s_x  <= in_x;
            s_y  <= in_y;
            s_rgb <= in_rgb;
            s_panel <= in_panel;
            s_bar <= in_bar;
            s_heavy <= selected && (abs_item == 4'd0);
            s_accent <= in_bar && (in_x >= (X0 + 16)) && (in_x < (X0 + 20)) && (yin < 13'd32);
            if(header && (col >= 5'd20))
                s_ink <= C_BLUE;
            else if(selected && (abs_item == 4'd0))
                s_ink <= C_HEAVY_INK;
            else if(selected || header)
                s_ink <= C_TEXT;
            else
                s_ink <= C_DIM;
        end

        m_hit <= s_hit;
        m_bit <= s_bit;
        m_vs <= s_vs; m_hs <= s_hs; m_de <= s_de;
        m_x <= s_x; m_y <= s_y; m_rgb <= s_rgb;
        m_panel <= s_panel; m_bar <= s_bar; m_heavy <= s_heavy; m_accent <= s_accent;
        m_ink <= s_ink;
`ifdef MENU_SIM
        rom_raw <= imem[s_addr];
`endif
        d_word <= rom_raw;
        d_hit <= m_hit;
        d_bit <= m_bit;
        d_vs <= m_vs; d_hs <= m_hs; d_de <= m_de;
        d_x <= m_x; d_y <= m_y; d_rgb <= m_rgb;
        d_panel <= m_panel; d_bar <= m_bar; d_heavy <= m_heavy; d_accent <= m_accent;
        d_ink <= m_ink;

        out_vsync <= d_vs;
        out_hsync <= d_hs;
        out_de    <= d_de;
        out_x     <= d_x;
        out_y     <= d_y;
        if(d_accent)
            out_rgb <= C_BLUE;
        else if(d_hit && d_word[d_bit])
            out_rgb <= d_ink;
        else if(d_heavy)
            out_rgb <= C_HEAVY;
        else if(d_bar)
            out_rgb <= C_BAR;
        else if(d_panel)
            out_rgb <= {dim8(d_rgb[23:16]), dim8(d_rgb[15:8]), dim8(d_rgb[7:0])};
        else
            out_rgb <= d_rgb;
    end
end

`ifndef MENU_SIM
osd_infor_rom u_menu_font (
    .doa                        (rom_raw                    ),
    .addra                      (s_addr                     ),
    .clka                       (clk                        )
);
`endif

endmodule
