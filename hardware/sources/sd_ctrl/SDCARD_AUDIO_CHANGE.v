`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Create Date: 2026/10/11 09:21:17
// Module Name: SDCARD_AUDIO_CHANGE
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
//   输入是按键消抖后的单周期 flag。先做上升沿，多拍高电平也只算一次。
//   第一次打开 2 秒窗口，当时不输出。
//   窗口内再来一次：当拍给出上一首，并锁住本窗口剩余时间。
//   窗口走完仍然只有一次：给出下一首。
//   两秒内超过两次只产生一次上一首，多出来的 flag 丢掉，
//   避免三连按在两秒后再补一次下一首。窗口从第一次按下起算，不顺延。
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module SDCARD_AUDIO_CHANGE #(
    parameter                   CLK_FREQ                    = 50_000_000
)(
    input   wire                clk                         ,
    input   wire                reset                       ,

    input   wire                sd_audio_change_in          ,

    output  reg                 sd_audio_previous           ,
    output  reg                 sd_audio_next               
);

localparam integer              GAP_CYCLES                  = CLK_FREQ * 2;
localparam integer              CNT_W                       = $clog2(GAP_CYCLES);
localparam                      ST_IDLE                     = 2'd0;
localparam                      ST_ARM                      = 2'd1;
localparam                      ST_LOCK                     = 2'd2;

reg     [1:0]                   state                       ;
reg     [CNT_W-1:0]             cnt                         ;
reg                             change_d                    ;
wire                            change_pulse                ;

assign change_pulse = sd_audio_change_in & ~change_d;

always@(posedge clk) begin
    if(reset) begin
        change_d <= 1'b0;
    end
    else begin
        change_d <= sd_audio_change_in;
    end
end

always@(posedge clk) begin
    if(reset) begin
        state              <= ST_IDLE;
        cnt                <= {CNT_W{1'b0}};
        sd_audio_previous  <= 1'b0;
        sd_audio_next      <= 1'b0;
    end
    else begin
        sd_audio_previous <= 1'b0;
        sd_audio_next     <= 1'b0;
        case(state)
            ST_IDLE : begin
                cnt <= {CNT_W{1'b0}};
                if(change_pulse) begin
                    state <= ST_ARM;
                end
            end
            ST_ARM : begin
                if(change_pulse) begin
                    sd_audio_previous <= 1'b1;
                    state             <= ST_LOCK;
                end
                else if(cnt == GAP_CYCLES - 1) begin
                    sd_audio_next <= 1'b1;
                    state         <= ST_IDLE;
                    cnt           <= {CNT_W{1'b0}};
                end
                else begin
                    cnt <= cnt + 1'b1;
                end
            end
            ST_LOCK : begin
                if(cnt == GAP_CYCLES - 1) begin
                    cnt <= {CNT_W{1'b0}};
                    if(change_pulse) begin
                        state <= ST_ARM;
                    end
                    else begin
                        state <= ST_IDLE;
                    end
                end
                else begin
                    cnt <= cnt + 1'b1;
                end
            end
            default : begin
                state <= ST_IDLE;
            end
        endcase
    end
end

endmodule
