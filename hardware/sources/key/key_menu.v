`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: key_menu
// Description: 拨码 2 打开时，左/确认/右浏览串口那一组参数。
//              确认进入或返回。数值左右即改，再按确认回到列表。
//              开关项按确认翻转。串口帧仍然写同一组寄存器，后一次生效。
//              拨码 0 只显示在菜单角标上，不切断另一路。
//              按住左或右约 0.4 秒后开始重复。
//////////////////////////////////////////////////////////////////////////////////

module key_menu #(
    parameter                   CLK_FREQ                    = 75_000_000
)(
    input   wire                clk                             ,
    input   wire                reset                           ,

    input   wire                sw0_in                          ,
    input   wire                sw2_in                          ,
    input   wire                nav_left                        ,
    input   wire                nav_ok                          ,
    input   wire                nav_right                       ,

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

    output  reg                 menu_on                         ,
    output  reg                 menu_uart                       ,
    output  reg     [2:0]       menu_page                       ,
    output  reg     [3:0]       menu_item                       ,
    output  reg                 menu_edit                       ,

    output  reg                 key_we                          ,
    output  reg     [5:0]       key_id                          ,
    output  reg     [12:0]      key_data
);

localparam integer              HOLD_FIRST                  = (CLK_FREQ / 5) * 2;
localparam integer              HOLD_REP                    = (CLK_FREQ / 16) < 1 ? 1 : (CLK_FREQ / 16);

reg                             sw0_s1, sw0_s2                  ;
reg                             sw2_s1, sw2_s2                  ;
reg                             l1, l2, l_d                     ;
reg                             o1, o2, o_d                     ;
reg                             r1, r2, r_d                     ;
reg     [1:0]                   depth                           ;
reg     [31:0]                  l_hold, r_hold                  ;
reg                             l_phase, r_phase                ;

wire                            left_rise                       ;
wire                            ok_rise                         ;
wire                            right_rise                      ;

assign left_rise  = l2 & ~l_d;
assign ok_rise    = o2 & ~o_d;
assign right_rise = r2 & ~r_d;

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

function signed [9:0] step_mag;
    input [2:0] page;
    input [3:0] item;
    input       big;
    begin
        case({page, item})
            {3'd0, 4'd2}, {3'd0, 4'd3},
            {3'd2, 4'd2},
            {3'd4, 4'd5}, {3'd4, 4'd6},
            {3'd5, 4'd2}:
                step_mag = 10'sd1;
            {3'd1, 4'd2}, {3'd1, 4'd3}, {3'd1, 4'd4}, {3'd1, 4'd5},
            {3'd2, 4'd3}:
                step_mag = big ? 10'sd8 : 10'sd1;
            {3'd4, 4'd4}, {3'd6, 4'd2}, {3'd6, 4'd3}:
                step_mag = big ? 10'sd32 : 10'sd8;
            default:
                step_mag = big ? 10'sd32 : 10'sd4;
        endcase
    end
endfunction

task emit;
    input [5:0]  id;
    input [12:0] val;
    begin
        key_we   <= 1'b1;
        key_id   <= id;
        key_data <= val;
    end
endtask

// 各分支只记下步长。真正的加法和饱和只在时钟末尾做一次，避免综合复制 30 多份加法器。
reg                             pend_edit                       ;
reg signed [9:0]                edit_del                        ;

task apply_delta;
    input signed [9:0] del;
    begin
        pend_edit = 1'b1;
        edit_del  = del;
    end
endtask

task edit_apply;
    reg [5:0]         id;
    reg [12:0]        cur;
    reg [12:0]        lo;
    reg [12:0]        hi;
    reg [12:0]        nxt;
    reg signed [14:0] sum;
    begin
        id  = 6'd63;
        cur = 13'd0;
        lo  = 13'd0;
        hi  = 13'd0;
        case({menu_page, menu_item})
            {3'd0, 4'd2}: begin id = 6'd1;  cur = {10'd0, cut_mode}; hi = 13'd7; end
            {3'd0, 4'd3}: begin id = 6'd2;  cur = {11'd0, cut_speed}; hi = 13'd3; end
            {3'd1, 4'd2}: begin id = 6'd4;  cur = {5'd0, lumi}; hi = 13'd255; end
            {3'd1, 4'd3}: begin id = 6'd5;  cur = {5'd0, contrast}; hi = 13'd255; end
            {3'd1, 4'd4}: begin id = 6'd6;  cur = {5'd0, temp}; hi = 13'd255; end
            {3'd1, 4'd5}: begin id = 6'd7;  cur = {5'd0, tint}; hi = 13'd255; end
            {3'd2, 4'd2}: begin id = 6'd9;  cur = {10'd0, (style_mode <= 3'd3) ? style_mode : 3'd0}; hi = 13'd3; end
            {3'd2, 4'd3}: begin id = 6'd10; cur = {5'd0, style_th}; hi = 13'd255; end
            {3'd3, 4'd2}: begin id = 6'd13; cur = logo_x; hi = 13'd1200; end
            {3'd3, 4'd3}: begin id = 6'd14; cur = logo_y; hi = 13'd640; end
            {3'd4, 4'd2}: begin id = 6'd16; cur = txt_x; hi = 13'd1200; end
            {3'd4, 4'd3}: begin id = 6'd17; cur = txt_y; hi = 13'd688; end
            {3'd4, 4'd4}: begin id = 6'd18; cur = txt_w; lo = 13'd32; hi = 13'd1280; end
            {3'd4, 4'd5}: begin id = 6'd19; cur = {11'd0, txt_speed}; hi = 13'd3; end
            {3'd4, 4'd6}: begin id = 6'd20; cur = (txt_cmode == 2'd1) ? 13'd1 : 13'd0; hi = 13'd1; end
            {3'd5, 4'd2}: begin id = 6'd26; cur = (aud_cmode == 2'd1) ? 13'd1 : 13'd0; hi = 13'd1; end
            {3'd5, 4'd3}: begin id = 6'd30; cur = aud_x; hi = 13'd1200; end
            {3'd5, 4'd4}: begin id = 6'd31; cur = aud_y; hi = 13'd640; end
            {3'd6, 4'd2}: begin id = 6'd33; cur = scale_w; lo = 13'd8; hi = 13'd1280; end
            {3'd6, 4'd3}: begin id = 6'd34; cur = scale_h; lo = 13'd8; hi = 13'd720; end
            default: begin
            end
        endcase
        if(id != 6'd63) begin
            sum = $signed({2'b0, cur}) + edit_del;
            if(sum < $signed({2'b0, lo}))
                nxt = lo;
            else if(sum > $signed({2'b0, hi}))
                nxt = hi;
            else
                nxt = sum[12:0];
            emit(id, nxt);
        end
    end
endtask

task move_sel;
    input signed [4:0] dir;
    input              big;
    reg signed [9:0]   del;
    begin
        if(depth == 2'd0) begin
            if((dir < 0) && (menu_page != 3'd0))
                menu_page <= menu_page - 3'd1;
            else if((dir > 0) && (menu_page != 3'd6))
                menu_page <= menu_page + 3'd1;
        end
        else if(depth == 2'd1) begin
            if((dir < 0) && (menu_item != 4'd0))
                menu_item <= menu_item - 4'd1;
            else if((dir > 0) && (menu_item + 4'd1 < n_of(menu_page)))
                menu_item <= menu_item + 4'd1;
        end
        else begin
            del = step_mag(menu_page, menu_item, big);
            if(dir < 0)
                del = -del;
            apply_delta(del);
        end
    end
endtask

task press_ok;
    begin
        if(depth == 2'd0) begin
            depth     <= 2'd1;
            menu_item <= 4'd1;
        end
        else if(depth == 2'd2) begin
            depth <= 2'd1;
        end
        else if(menu_item == 4'd0) begin
            depth <= 2'd0;
        end
        else if(menu_item == 4'd1) begin
            case(menu_page)
                3'd0: emit(6'd0,  {12'd0, ~cut_disable});
                3'd1: emit(6'd3,  {12'd0, ~color_disable});
                3'd2: emit(6'd8,  {12'd0, ~style_disable});
                3'd3: emit(6'd12, {12'd0, ~osd_disable});
                3'd4: emit(6'd15, {12'd0, ~txt_disable});
                3'd5: emit(6'd24, {12'd0, ~aud_disable});
                default: emit(6'd32, {12'd0, ~scale_disable});
            endcase
        end
        else
            depth <= 2'd2;
    end
endtask

always @(posedge clk) begin
    if(reset) begin
        sw0_s1 <= 1'b0; sw0_s2 <= 1'b0;
        sw2_s1 <= 1'b0; sw2_s2 <= 1'b0;
        l1 <= 1'b0; l2 <= 1'b0; l_d <= 1'b0;
        o1 <= 1'b0; o2 <= 1'b0; o_d <= 1'b0;
        r1 <= 1'b0; r2 <= 1'b0; r_d <= 1'b0;
        depth <= 2'd0;
        menu_page <= 3'd0;
        menu_item <= 4'd0;
        l_hold <= 32'd0;
        r_hold <= 32'd0;
        l_phase <= 1'b0;
        r_phase <= 1'b0;
        key_we <= 1'b0;
        key_id <= 6'd0;
        key_data <= 13'd0;
    end
    else begin
        sw0_s1 <= sw0_in; sw0_s2 <= sw0_s1;
        sw2_s1 <= sw2_in; sw2_s2 <= sw2_s1;
        l1 <= nav_left;  l2 <= l1;  l_d <= l2;
        o1 <= nav_ok;    o2 <= o1;  o_d <= o2;
        r1 <= nav_right; r2 <= r1;  r_d <= r2;
        key_we <= 1'b0;
        pend_edit = 1'b0;

        if(!sw2_s2) begin
            depth   <= 2'd0;
            l_hold  <= 32'd0;
            r_hold  <= 32'd0;
            l_phase <= 1'b0;
            r_phase <= 1'b0;
        end
        else if(ok_rise) begin
            press_ok;
        end
        else if(left_rise) begin
            l_hold  <= 32'd0;
            l_phase <= 1'b0;
            move_sel(-5'sd1, 1'b0);
        end
        else if(right_rise) begin
            r_hold  <= 32'd0;
            r_phase <= 1'b0;
            move_sel(5'sd1, 1'b0);
        end
        else if(l2) begin
            if(!l_phase && (l_hold == HOLD_FIRST - 1)) begin
                l_hold  <= 32'd0;
                l_phase <= 1'b1;
                move_sel(-5'sd1, 1'b1);
            end
            else if(l_phase && (l_hold == HOLD_REP - 1)) begin
                l_hold <= 32'd0;
                move_sel(-5'sd1, 1'b1);
            end
            else
                l_hold <= l_hold + 32'd1;
        end
        else if(r2) begin
            if(!r_phase && (r_hold == HOLD_FIRST - 1)) begin
                r_hold  <= 32'd0;
                r_phase <= 1'b1;
                move_sel(5'sd1, 1'b1);
            end
            else if(r_phase && (r_hold == HOLD_REP - 1)) begin
                r_hold <= 32'd0;
                move_sel(5'sd1, 1'b1);
            end
            else
                r_hold <= r_hold + 32'd1;
        end
        else begin
            l_hold  <= 32'd0;
            r_hold  <= 32'd0;
            l_phase <= 1'b0;
            r_phase <= 1'b0;
        end
        if(pend_edit)
            edit_apply;
    end
end

always @(posedge clk) begin
    menu_on   <= sw2_s2;
    menu_uart <= sw0_s2;
    menu_edit <= sw2_s2 && (depth == 2'd2);
end

endmodule
