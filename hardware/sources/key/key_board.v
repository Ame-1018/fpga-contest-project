`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: key_board
// Description: 独立按键低电平有效，消抖后给出按下电平和单拍。
//              拨码 1 为 1 时自动切图。
//              拨码 1 和 3 都为 0 时，按键 3 切下一张。
//              拨码 1 为 1 且拨码 3 为 0 时，按键 3 切下一首。
//              拨码 1 和 3 都为 1 时，按键 3 重新读下一组图片。
//              拨码 1 为 0 且拨码 3 为 1 时，按键 3 不动作。
//              拨码 2 为 1 时按键 2/1/0 交给菜单，按键 1 不再重载图片。
//              悬空或未知电平：按键当松开，拨码当 0。
//////////////////////////////////////////////////////////////////////////////////

module key_board #(
    parameter                   CLK_FREQ                    = 50_000_000
)(
    input   wire                clk                             ,
    input   wire                reset                           ,

    input   wire    [3:0]       key_in                          ,
    input   wire    [3:0]       sw_in                           ,

    output  reg     [3:0]       sw_level                        ,
    output  wire                nav_right                       ,
    output  wire                nav_ok                          ,
    output  wire                nav_left                        ,
    output  reg                 pic_tog                         ,
    output  reg                 audio_next_pulse                ,
    output  reg                 bmp_init_pulse
);

localparam integer              CNT_MAX                     = (CLK_FREQ / 50) - 1;
localparam integer              CNT_W                       = (CNT_MAX < 2) ? 1 : $clog2(CNT_MAX + 1);

wire    [3:0]                   key_n                           ;
wire    [3:0]                   sw_pin                          ;
wire    [3:0]                   key_pulse                       ;
reg     [3:0]                   held                            ;
reg     [CNT_W-1:0]             sw_cnt          [0:3]           ;
integer                         si                              ;

assign key_n[0] = (key_in[0] == 1'b0) ? 1'b0 : 1'b1;
assign key_n[1] = (key_in[1] == 1'b0) ? 1'b0 : 1'b1;
assign key_n[2] = (key_in[2] == 1'b0) ? 1'b0 : 1'b1;
assign key_n[3] = (key_in[3] == 1'b0) ? 1'b0 : 1'b1;
assign sw_pin[0] = (sw_in[0] == 1'b1) ? 1'b1 : 1'b0;
assign sw_pin[1] = (sw_in[1] == 1'b1) ? 1'b1 : 1'b0;
assign sw_pin[2] = (sw_in[2] == 1'b1) ? 1'b1 : 1'b0;
assign sw_pin[3] = (sw_in[3] == 1'b1) ? 1'b1 : 1'b0;

assign nav_right = held[0];
assign nav_ok    = held[1];
assign nav_left  = held[2];

genvar gi;
generate
    for(gi = 0; gi < 4; gi = gi + 1) begin : g_key
        key_filter #(
            .CLK_FREQ               (CLK_FREQ                   )
        ) u_key (
            .sys_clk                (clk                        ),
            .sys_rst                (reset                      ),
            .key_in                 (key_n[gi]                  ),
            .key_flag               (key_pulse[gi]              )
        );
    end
endgenerate

always @(posedge clk) begin
    if(reset) begin
        held <= 4'b0;
    end
    else begin
        held[0] <= key_n[0] ? 1'b0 : (held[0] | key_pulse[0]);
        held[1] <= key_n[1] ? 1'b0 : (held[1] | key_pulse[1]);
        held[2] <= key_n[2] ? 1'b0 : (held[2] | key_pulse[2]);
        held[3] <= key_n[3] ? 1'b0 : (held[3] | key_pulse[3]);
    end
end

always @(posedge clk) begin
    if(reset) begin
        for(si = 0; si < 4; si = si + 1)
            sw_cnt[si] <= {CNT_W{1'b0}};
        sw_level <= 4'b0;
    end
    else begin
        for(si = 0; si < 4; si = si + 1) begin
            if(sw_pin[si] == sw_level[si])
                sw_cnt[si] <= {CNT_W{1'b0}};
            else if(sw_cnt[si] == CNT_MAX) begin
                sw_level[si] <= sw_pin[si];
                sw_cnt[si]   <= {CNT_W{1'b0}};
            end
            else
                sw_cnt[si] <= sw_cnt[si] + 1'b1;
        end
    end
end

always @(posedge clk) begin
    if(reset) begin
        pic_tog          <= 1'b0;
        audio_next_pulse <= 1'b0;
        bmp_init_pulse   <= 1'b0;
    end
    else begin
        audio_next_pulse <= key_pulse[3] && sw_level[1] && !sw_level[3];
        bmp_init_pulse   <= (key_pulse[3] && sw_level[1] && sw_level[3]) ||
                            (key_pulse[1] && !sw_level[2]);
        if(key_pulse[3] && !sw_level[1] && !sw_level[3])
            pic_tog <= ~pic_tog;
    end
end

endmodule
