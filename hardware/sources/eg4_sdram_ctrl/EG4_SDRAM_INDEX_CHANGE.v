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

module EG4_SDRAM_INDEX_CHANGE #(
    parameter                   CLK_FREQ                    = 150_000_000
)(
    input   wire                clk                         ,
    input   wire                reset                       ,

    input   wire                sdram_index_change_auto     ,// auto : 1 ; manual : 0;
    input   wire    [7:0]       sdram_index_change_time     ,// auto change frame rate 
    input   wire                sdram_index_change_flag     ,// manual change

    input   wire    [2:0]       sdram_set_index_max         ,

    output  reg                 sdram_picturex_change       ,
    output  reg     [2:0]       sdram_picture1_index        ,
    output  reg     [2:0]       sdram_picture2_index        ,

    input   wire                sdram_change_done_tog       ,
    input   wire                hdmi_vsync                  ,
    input   wire                cut_disable
);

localparam integer HDMI_HTOTAL = 2200;
localparam integer HDMI_VTOTAL = 1125;

reg                             sdram_index_change_auto_r   ;
reg     [7:0]                   sdram_index_change_time_r   ;
reg                             sdram_index_change_flag_r   ;
reg     [2:0]                   sdram_set_index_max_r       ;

reg     [12:0]                  hdmi_xcnt                   = 0;
reg     [12:0]                  hdmi_vcnt                   = 0;
reg                             x_last                      = 0;
reg                             y_last                      = 0;
reg                             hdmi_vsync_flag             = 0;
reg     [7:0]                   hdmi_vsync_cnt              = 0;
reg                             hdmi_vsync_auto_flag        ;

reg     [2:0]                   hdmi_dis_index1             ;
wire    [2:0]                   hdmi_dis_index2             ;
reg                             freeze                      ;
reg                             advance                     ;
reg                             done_s1, done_s2, done_s3   ;
reg                             hdmi_vs1, hdmi_vs2          ;
wire                            done_pulse                  ;
wire                            hdmi_vs_pos                 ;
wire                            change_flag                 ;
reg                             dis_s1, dis_s2              ;

always@(posedge clk) begin
    sdram_index_change_auto_r <= sdram_index_change_auto;
    sdram_index_change_time_r <= sdram_index_change_time;
    sdram_index_change_flag_r <= sdram_index_change_flag;

    sdram_set_index_max_r <= sdram_set_index_max;
end

always@(posedge clk) begin
    x_last <= (hdmi_xcnt == HDMI_HTOTAL - 2);
    y_last <= (hdmi_vcnt == HDMI_VTOTAL - 1);
    hdmi_xcnt <= x_last ? 13'd0 : hdmi_xcnt + 13'd1;
    hdmi_vcnt <= (x_last && y_last) ? 13'd0 :
                 (x_last ? hdmi_vcnt + 13'd1 : hdmi_vcnt);
end

always@(posedge clk) begin
    hdmi_vsync_flag <= x_last && y_last;
end

always@(posedge clk) begin
    if(reset) begin
        hdmi_vsync_cnt <= 8'd0;
    end
    else if(hdmi_vsync_flag && hdmi_vsync_cnt == sdram_index_change_time_r - 1'b1) begin
        hdmi_vsync_cnt <= 8'd0;
    end
    else if(hdmi_vsync_flag) begin
        hdmi_vsync_cnt <= hdmi_vsync_cnt + 1'b1;
    end

    hdmi_vsync_auto_flag <= hdmi_vsync_flag && hdmi_vsync_cnt == sdram_index_change_time_r - 1'b1;
end


assign done_pulse = done_s2 ^ done_s3;
assign hdmi_vs_pos = hdmi_vs1 && !hdmi_vs2;

always@(posedge clk) begin
    if(reset) begin
        done_s1 <= 1'b0;
        done_s2 <= 1'b0;
        done_s3 <= 1'b0;
        hdmi_vs1 <= 1'b0;
        hdmi_vs2 <= 1'b0;
        dis_s1 <= 1'b0;
        dis_s2 <= 1'b0;
        freeze <= 1'b0;
        advance <= 1'b0;
    end
    else begin
        done_s1 <= sdram_change_done_tog;
        done_s2 <= done_s1;
        done_s3 <= done_s2;
        hdmi_vs1 <= hdmi_vsync;
        hdmi_vs2 <= hdmi_vs1;
        dis_s1 <= cut_disable;
        dis_s2 <= dis_s1;
        if(advance && hdmi_vs_pos) begin
            advance <= 1'b0;
            freeze  <= 1'b0;
        end
        else if(done_pulse && freeze)
            advance <= 1'b1;
        else if(change_flag && !dis_s2)
            freeze <= 1'b1;
    end
end

always@(posedge clk) begin
    if(reset) begin
        hdmi_dis_index1 <= 3'd0;
        sdram_picture1_index <= 3'd0;
        sdram_picture2_index <= 3'd1;
    end
    else if(dis_s2 && change_flag && hdmi_dis_index1 == sdram_set_index_max_r - 1'b1) begin
        hdmi_dis_index1 <= 3'd0;
        sdram_picture1_index <= 3'd0;
        sdram_picture2_index <= 3'd1;
    end
    else if(dis_s2 && change_flag) begin
        hdmi_dis_index1 <= hdmi_dis_index1 + 1'b1;
        sdram_picture1_index <= hdmi_dis_index1 + 1'b1;
        sdram_picture2_index <= (hdmi_dis_index1 + 3'd2 == sdram_set_index_max_r) ? 3'd0 :
                                (hdmi_dis_index1 + 3'd2);
    end
    else if(advance && hdmi_vs_pos && hdmi_dis_index1 == sdram_set_index_max_r - 1'b1) begin
        hdmi_dis_index1 <= 3'd0;
        sdram_picture1_index <= 3'd0;
        sdram_picture2_index <= 3'd1;
    end
    else if(advance && hdmi_vs_pos) begin
        hdmi_dis_index1 <= hdmi_dis_index1 + 1'b1;
        sdram_picture1_index <= hdmi_dis_index1 + 1'b1;
        sdram_picture2_index <= (hdmi_dis_index1 + 3'd2 == sdram_set_index_max_r) ? 3'd0 :
                                (hdmi_dis_index1 + 3'd2);
    end
end

// always@(posedge clk) begin
//     if(reset) begin
//         hdmi_dis_index2 <= 3'd1;
//     end
//     else if(sdram_index_change_auto_r == 1'b1 && hdmi_vsync_auto_flag && hdmi_dis_index1 == sdram_set_index_max_r - 1'b1) begin
//         hdmi_dis_index2 <= 3'd1;
//     end
//     else if(sdram_index_change_auto_r == 1'b1 && hdmi_vsync_auto_flag) begin
//         hdmi_dis_index2 <= hdmi_dis_index1 + 1'b1;
//     end
//     else if(sdram_index_change_auto_r == 1'b0 && sdram_index_change_flag_r && hdmi_dis_index1 == sdram_set_index_max_r - 1'b1) begin
//         hdmi_dis_index2 <= 3'd1;
//     end
//     else if(sdram_index_change_auto_r == 1'b0 && sdram_index_change_flag_r) begin
//         hdmi_dis_index2 <= hdmi_dis_index1 + 1'b1;
//     end
// end

assign hdmi_dis_index2 = (hdmi_dis_index1 == sdram_set_index_max_r - 1'b1) ? 3'd0 : hdmi_dis_index1 + 1'b1;


/*----------------------------------------------------------*/

//
reg                             change_hold                 ;
reg     [3:0]                   change_cnt                  ;

assign change_flag = !freeze && (sdram_index_change_auto_r ? hdmi_vsync_auto_flag : sdram_index_change_flag_r);


always@(posedge clk) begin
    if(reset) begin
        change_hold <= 1'b0;
    end
    else if(change_hold && change_cnt == 4'd15) begin
        change_hold <= 1'b0;
    end
    else if(change_flag) begin
        change_hold <= 1'b1;
    end
end

always@(posedge clk) begin
    if(change_hold) begin
        change_cnt <= change_cnt + 1'b1;
    end
    else begin
        change_cnt <= 4'd0;
    end
end

always@(posedge clk) begin
    sdram_picturex_change <= change_hold;
end


endmodule
