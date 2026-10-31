`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Create Date: 2026/10/08 09:21:17
// Design Name: 
// Module Name: EG4_SDRAM_INDEX_CHANGE
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module AUDIO_ARC_TOP #(
    parameter                   CLK_FREQ                    = 75_000_000
)(
    input   wire                clk                         ,
    input   wire                reset                       ,

    input   wire                audio_enable                ,

    output  reg                 sd_audio_req                ,
    input   wire                sd_audio_ack                ,
    input   wire    [47:0]      sd_audio_data               ,

    output  reg                 audio_data_valid            ,
    output  reg     [23:0]      audio_data_left             ,
    output  reg     [23:0]      audio_data_right            ,

    output  reg                 audio_arc_valid             ,
    output  reg     [19:0]      audio_arc_cts               ,
    output  reg     [19:0]      audio_arc_n                  
);

parameter                       AUDIO_DIV_NUB               = (CLK_FREQ * 2) / 48_000;
parameter                       AUDIO_DIV_CNT1              = (AUDIO_DIV_NUB / 2);
parameter                       AUDIO_DIV_CNT2              = (AUDIO_DIV_NUB / 2) + AUDIO_DIV_NUB[0];

reg     [19:0]                  clk_div_cnt                 ;
reg                             clk_div_flag1               ;
reg                             clk_div_flag2               ;


always@(posedge clk) begin
    if(reset) begin
        clk_div_cnt <= 20'd0;
    end
    else if(audio_enable && clk_div_cnt == AUDIO_DIV_NUB - 1'b1) begin
        clk_div_cnt <= 20'd0;
    end
    else if(audio_enable) begin
        clk_div_cnt <= clk_div_cnt + 1'b1;
    end
    else begin
        clk_div_cnt <= 20'd0;
    end

    clk_div_flag1 <= audio_enable && clk_div_cnt == AUDIO_DIV_CNT1 - 1'b1;
    clk_div_flag2 <= audio_enable && clk_div_cnt == AUDIO_DIV_NUB - 1'b1;
end

always@(posedge clk) begin
    sd_audio_req <= clk_div_flag1 | clk_div_flag2;
end

always@(posedge clk) begin
    if(sd_audio_ack) begin
        audio_data_valid    <= 1'b1;
        audio_data_left     <= sd_audio_data[24*1+:24];
        audio_data_right    <= sd_audio_data[24*0+:24];
    end
    else begin
        audio_data_valid    <= 1'b0;
        audio_data_left     <= 24'd0;
        audio_data_right    <= 24'd0;
    end
end

/*----------------------------------------------------------*/
parameter                       ACR_N                       = 6144;
parameter                       ARC_DIV                     = ACR_N >> 7;

wire                            arc_time_flag               ;

reg     [7:0]                   arc_div_cnt                 ;
reg     [19:0]                  arc_cts_cnt                 ;

wire                            arc_out_flag                ;

assign arc_time_flag = clk_div_flag1 | clk_div_flag2;

always@(posedge clk) begin
    if(reset) begin
        arc_div_cnt <= 8'd0;
    end
    else if(arc_out_flag) begin
        arc_div_cnt <= 8'd0;
    end
    else if(audio_enable && arc_time_flag) begin
        arc_div_cnt <= arc_div_cnt + 1'b1;
    end
    else if(!audio_enable) begin
        arc_div_cnt <= 20'd0;
    end
end

assign arc_out_flag = audio_enable && arc_time_flag && arc_div_cnt == ARC_DIV - 1'b1;

always@(posedge clk) begin
    if(reset) begin
        arc_cts_cnt <= 20'd0;
    end
    else if(audio_enable && arc_out_flag) begin
        arc_cts_cnt <= 20'd0;
    end
    else if(audio_enable) begin
        arc_cts_cnt <= arc_cts_cnt + 1'b1;
    end
    else begin
        arc_cts_cnt <= 20'd0;
    end
end

always@(posedge clk) begin
    if(arc_out_flag) begin
        audio_arc_valid <= 1'b1;
        audio_arc_cts   <= arc_cts_cnt + 1'b1;
        audio_arc_n     <= ACR_N;
    end
    else begin
        audio_arc_valid <= 1'b0;
        audio_arc_cts   <= 20'd0;
        audio_arc_n     <= 20'd0;
    end
end
        


endmodule
