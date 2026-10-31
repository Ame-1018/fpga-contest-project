`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: EG4_SDRAM_RD_SEL
// Description: 写口不经过本模块。读口 1 在顺序读和缩放读之间切换，读口 2
//              在缩放运行时关闭。切换发生在当前这一路空闲且不在有效区的时候。
//              没被选中的那一路请求不计入忙，否则关缩放或开始转场时
//              顺序读请求先拉高、又得不到允许，切换永远等不到空闲，画面变黑。
//////////////////////////////////////////////////////////////////////////////////

module EG4_SDRAM_RD_SEL(
    input   wire                clk                         ,
    input   wire                reset                       ,

    input   wire                want_scale                  ,
    input   wire                video_de                    ,

    input   wire                rd1_req                     ,
    input   wire                rd1_end                     ,
    input   wire                rd2_req                     ,
    input   wire                rd2_end                     ,
    input   wire                scale_req                   ,
    input   wire                scale_end                   ,

    input   wire                rd1_en                      ,
    input   wire    [20:0]      rd1_addr                    ,
    input   wire                rd2_en                      ,
    input   wire    [20:0]      rd2_addr                    ,
    input   wire                scale_en                    ,
    input   wire    [20:0]      scale_addr                  ,

    input   wire    [2:0]       allow                       ,
    input   wire                sdr_dv                      ,
    input   wire    [31:0]      sdr_data                    ,

    output  wire                req1                        ,
    output  wire                req2                        ,
    output  wire                end1                        ,
    output  wire                end2                        ,
    output  wire                rd1_allow                   ,
    output  wire                rd2_allow                   ,
    output  wire                scale_allow                 ,

    output  wire                app_en                      ,
    output  wire    [20:0]      app_addr                    ,
    output  wire                rd1_dv                      ,
    output  wire                rd2_dv                      ,
    output  wire                scale_dv                    ,
    output  wire    [31:0]      rd1_data                    ,
    output  wire    [31:0]      rd2_data                    ,
    output  wire    [31:0]      scale_data                  ,

    output  reg                 use_scale
);

reg     [2:0]                   want_s                      ;
reg     [2:0]                   de_s                        ;
wire                            want                        ;
wire                            de_now                      ;
wire                            busy                        ;

always@(posedge clk) begin
    if(reset) begin
        want_s <= 3'd0;
        de_s   <= 3'd0;
    end
    else begin
        want_s <= {want_s[1:0], want_scale};
        de_s   <= {de_s[1:0], video_de};
    end
end

assign want   = want_s[2];
assign de_now = de_s[2];
assign busy   = use_scale ? (allow[1] || scale_req)
                          : (allow[1] || allow[2] || rd1_req || rd2_req);

always@(posedge clk) begin
    if(reset)
        use_scale <= 1'b0;
    else if((use_scale != want) && !busy && !de_now)
        use_scale <= want;
end

assign req1        = use_scale ? scale_req : rd1_req;
assign req2        = use_scale ? 1'b0      : rd2_req;
assign end1        = use_scale ? scale_end : rd1_end;
assign end2        = use_scale ? 1'b0      : rd2_end;
assign rd1_allow   = use_scale ? 1'b0      : allow[1];
assign rd2_allow   = use_scale ? 1'b0      : allow[2];
assign scale_allow = use_scale ? allow[1]  : 1'b0;

assign app_en   = use_scale ? (scale_allow && scale_en) :
                  (allow[1] ? rd1_en : (allow[2] ? rd2_en : 1'b0));
assign app_addr = use_scale ? scale_addr :
                  (allow[1] ? rd1_addr : (allow[2] ? rd2_addr : 21'd0));

assign rd1_dv      = (!use_scale && allow[1]) ? sdr_dv : 1'b0;
assign rd2_dv      = (!use_scale && allow[2]) ? sdr_dv : 1'b0;
assign scale_dv    = (use_scale && allow[1])  ? sdr_dv : 1'b0;
assign rd1_data    = sdr_data;
assign rd2_data    = sdr_data;
assign scale_data  = sdr_data;

endmodule
