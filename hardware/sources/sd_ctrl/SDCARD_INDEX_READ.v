`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Create Date: 2026/10/11 09:21:17
// Design Name: 
// Module Name: SDCARD_INDEX_READ
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


module SDCARD_INDEX_READ(
    input   wire                clk                         ,
    input   wire                reset                       ,

    input   wire                sd_init_done                ,

    input   wire                sd_index_init_flag          ,
    output  reg                 sd_index_init_done          ,

    output  reg                 sd_index_r_req              ,
    output  reg     [31:0]      sd_index_r_addr             ,
    input   wire                sd_index_r_ack              ,

    input   wire                sd_index_r_start            ,
    input   wire                sd_index_r_dv               ,
    input   wire    [7:0]       sd_index_r_data             ,
    input   wire                sd_index_r_end              ,
    input   wire    [8:0]       sd_index_r_cnt              ,
    input   wire                sd_index_r_err              ,

    output  reg                 sd_bmp_Structures_flag      ,
    output  reg     [3:0]       sd_bmp_Structures_cnt       ,
    output  reg     [81:0]      sd_bmp_Structures_data      ,//24+32+13+13

    output  reg                 sd_audio_Structures_flag    ,
    output  reg     [3:0]       sd_audio_Structures_cnt     ,
    output  reg     [97:0]      sd_audio_Structures_data     //24+32+32+4+6
);


localparam                      INDEX_START_SD_ADDR         = 32832 ;
// localparam                      INDEX_START_SD_ADDR         = 32864 ;
localparam                      INDEX_HEAD_BLENGTH          = 64    ;

parameter                       STA_INDEX_IDLE              = 3'd0  ,
                                STA_INDEX_REQ               = 3'd1  ,
                                STA_INDEX_HEAD              = 3'd2  ,
                                STA_INDEX_BMP_INDEX         = 3'd3  ,
                                STA_INDEX_AUDIO_INDEX       = 3'd4  ,
                                STA_INDEX_DELAY             = 3'd5  ,
                                STA_INDEX_DONE              = 3'd6  ,
                                STA_INDEX_ERR               = 3'd7  ;

reg     [2:0]                   sd_init_done_r3             ;
reg                             sd_init_done_pos            ;

reg                             read_start_r                ;
reg                             read_dv_r                   ;
reg     [7:0]                   read_data_r                 ;
reg                             read_end_r                  ;
reg     [8:0]                   read_cnt_r                  ;
reg                             read_err_r                  ;

reg                             index_start_flag            ;

reg                             index_state_fail_flag       ;

reg     [2:0]                   index_state                 ;
reg     [2:0]                   index_state_r               ;
reg     [2:0]                   index_state_rr              ;

reg                             index_state_change_flag     ;

reg     [7:0]                   head_type   [7:0]           ;
reg     [31:0]                  head_version                = 0;
reg     [31:0]                  head_bmp_total_nub          = 0;
reg     [31:0]                  head_audio_total_nub        = 0;
reg     [31:0]                  head_index_absolute_sector  = 0;
reg     [31:0]                  head_bmp_s_absolute_sector  = 0;
reg     [31:0]                  head_audio_s_absolute_sector= 0;
reg     [31:0]                  head_entry_byte_count       = 0;
reg     [31:0]                  head_sector_byte_count      = 0;
reg     [31:0]                  head_cluster_sector_count   = 0;
reg     [31:0]                  head_byte_count             = 0;
reg     [7:0]                   head_reserve    [11:0]      ;

reg     [8:0]                   head_bmp_end_cnt            ;
reg     [8:0]                   head_audio_end_cnt          ;
/*----------------------------------------------------------*/
reg                             type_bmp_hold               ;
reg     [7:0]                   type_bmp_index_cnt          ;
reg     [23:0]                  type_bmp_saddr              ;
reg     [31:0]                  type_bmp_blength            ;
reg     [31:0]                  type_bmp_width              ;
reg     [31:0]                  type_bmp_height             ;
reg                             type_bmp_save_flag          ;

reg                             type_audio_hold             ;
reg     [7:0]                   type_audio_index_cnt        ;
reg     [23:0]                  type_audio_saddr            ;
reg     [31:0]                  type_audio_blength          ;
reg     [31:0]                  type_audio_sampling_freq    ;
reg     [15:0]                  type_audio_channel_nub      ;
reg     [15:0]                  type_audio_bit_depth        ;
reg                             type_audio_save_flag        ;

reg                             index_done                  ;

function [12:0] abs13;
    input [12:0] data;
    begin
        if (data[12])
            abs13 = (~data) + 13'd1;
        else
            abs13 = abs13;
    end
endfunction

always@(posedge clk) begin
    read_start_r    <= sd_index_r_start     ;
    read_dv_r       <= sd_index_r_dv        ;
    read_data_r     <= sd_index_r_data      ;
    read_end_r      <= sd_index_r_end       ;
    read_cnt_r      <= sd_index_r_cnt       ;
    read_err_r      <= sd_index_r_err       ;
end

always@(posedge clk) begin
    sd_init_done_r3 <= {sd_init_done_r3[1:0],sd_init_done};
    sd_init_done_pos <= sd_init_done_r3[1] & !sd_init_done_r3[2];

    index_start_flag <= sd_init_done_pos | sd_index_init_flag | index_state == STA_INDEX_ERR ;
end

always@(posedge clk) begin
    if(reset) begin
        index_state <= STA_INDEX_IDLE;
    end
    else if(index_state_fail_flag) begin
        index_state <= STA_INDEX_ERR;
    end
    else begin
        case(index_state)
            STA_INDEX_IDLE          : begin if(index_start_flag)                                begin index_state <= STA_INDEX_REQ           ;end end
            STA_INDEX_REQ           : begin if(sd_index_r_ack)                                  begin index_state <= STA_INDEX_HEAD          ;end end
            STA_INDEX_HEAD          : begin if(read_cnt_r == 9'd63 && read_dv_r)                begin index_state <= STA_INDEX_BMP_INDEX     ;end end
            STA_INDEX_BMP_INDEX     : begin if(read_cnt_r == head_bmp_end_cnt && read_dv_r)     begin index_state <= STA_INDEX_AUDIO_INDEX   ;end end
            STA_INDEX_AUDIO_INDEX   : begin if(read_cnt_r == head_audio_end_cnt && read_dv_r)   begin index_state <= STA_INDEX_DELAY         ;end end
            STA_INDEX_DELAY         : begin                                                           index_state <= STA_INDEX_DONE          ;end 
            STA_INDEX_DONE          : begin                                                           index_state <= STA_INDEX_IDLE          ;end 
            STA_INDEX_ERR           : begin                                                           index_state <= STA_INDEX_IDLE          ;end
            default                 : begin                                                           index_state <= STA_INDEX_IDLE          ;end
        endcase
    end

    index_state_r <= index_state;
    index_state_rr <= index_state_r;

    index_state_change_flag <= index_state_rr != index_state_r;
end

always@(posedge clk) begin
    if(index_state == STA_INDEX_REQ && sd_index_r_ack) begin
        sd_index_r_req <= 1'b0;
    end
    else if(index_state == STA_INDEX_REQ) begin
        sd_index_r_req <= 1'b1;
    end

    
    if(index_state == STA_INDEX_REQ) begin
        sd_index_r_addr <= INDEX_START_SD_ADDR;
    end

end

always@(posedge clk) begin
    if(index_state_rr == STA_INDEX_HEAD) begin
        head_bmp_total_nub      [7:0] <= read_dv_r && read_cnt_r == 9'd12 ? read_data_r : head_bmp_total_nub[7:0];
        head_audio_total_nub    [7:0] <= read_dv_r && read_cnt_r == 9'd16 ? read_data_r : head_audio_total_nub[7:0];

        if(read_dv_r && (read_cnt_r >= 9'd20 && read_cnt_r <= 9'd23)) begin
            head_index_absolute_sector <= {read_data_r,head_index_absolute_sector[31:8]};
        end

        if(read_dv_r && (read_cnt_r >= 9'd24 && read_cnt_r <= 9'd27)) begin
            head_bmp_s_absolute_sector <= {read_data_r,head_bmp_s_absolute_sector[31:8]};
        end

        if(read_dv_r && (read_cnt_r >= 9'd28 && read_cnt_r <= 9'd31)) begin
            head_audio_s_absolute_sector <= {read_data_r,head_audio_s_absolute_sector[31:8]};
        end

        head_entry_byte_count       [7:0] <= read_dv_r && read_cnt_r == 9'd36 ? read_data_r : head_entry_byte_count[7:0];
        head_sector_byte_count      [7:0] <= read_dv_r && read_cnt_r == 9'd40 ? read_data_r : head_sector_byte_count[7:0];
        head_cluster_sector_count   [7:0] <= read_dv_r && read_cnt_r == 9'd44 ? read_data_r : head_cluster_sector_count[7:0];
        head_byte_count             [7:0] <= read_dv_r && read_cnt_r == 9'd48 ? read_data_r : head_byte_count[7:0];
    end
end

always@(posedge clk) begin
    head_bmp_end_cnt    <= 9'd64 + (head_bmp_total_nub[7:0] << 4) - 1'b1;
    head_audio_end_cnt  <= head_bmp_end_cnt + (head_audio_total_nub[7:0] << 4);
end

/*----------------------------------------------------------*/

always@(posedge clk) begin
    if(index_state_rr == STA_INDEX_BMP_INDEX) begin

        if(index_state_change_flag) begin
            type_bmp_index_cnt <= 8'd0;
        end
        else if(read_dv_r && read_cnt_r[3:0] == 4'd0 && read_data_r == 8'd1) begin
            type_bmp_index_cnt <= type_bmp_index_cnt + 1'b1;
        end

        if(read_dv_r && read_cnt_r[3:0] == 4'd15) begin
            type_bmp_hold <= 1'b0;
        end
        else if(read_dv_r && read_cnt_r[3:0] == 4'd0 && read_data_r == 8'd1) begin
            type_bmp_hold <= 1'b1;
        end

        if(read_dv_r && (read_cnt_r[3:0] >= 4'd1 && read_cnt_r[3:0] <= 4'd3)) begin
            type_bmp_saddr <= {read_data_r,type_bmp_saddr[23:8]};
        end

        if(read_dv_r && (read_cnt_r[3:0] >= 4'd4 && read_cnt_r[3:0] <= 4'd7)) begin
            type_bmp_blength <= {read_data_r,type_bmp_blength[31:8]};
        end

        if(read_dv_r && (read_cnt_r[3:0] >= 4'd8 && read_cnt_r[3:0] <= 4'd11)) begin
            type_bmp_width <= {read_data_r,type_bmp_width[31:8]};
        end

        if(read_dv_r && (read_cnt_r[3:0] >= 4'd12 && read_cnt_r[3:0] <= 4'd15)) begin
            type_bmp_height <= {read_data_r,type_bmp_height[31:8]};
        end

        type_bmp_save_flag <= read_dv_r && read_cnt_r[3:0] == 4'd15;
    end
    else begin
        type_bmp_save_flag <= 1'b0;
    end
end

always@(posedge clk) begin
    if(index_state_rr == STA_INDEX_BMP_INDEX) begin
        sd_bmp_Structures_flag  <= type_bmp_save_flag;
        sd_bmp_Structures_data  <= type_bmp_save_flag ? {type_bmp_saddr,type_bmp_blength,type_bmp_width[12:0],abs13(type_bmp_height[12:0])} : sd_bmp_Structures_data;
    end
    else begin
        sd_bmp_Structures_flag  <= 1'b0;
    end
end

always@(posedge clk) begin
    if(index_state_rr == STA_INDEX_BMP_INDEX) begin
        sd_bmp_Structures_cnt   <= sd_bmp_Structures_flag ? sd_bmp_Structures_cnt + 1'b1 : sd_bmp_Structures_cnt; 
    end
    else begin
        sd_bmp_Structures_cnt   <= 4'd0;
    end
end


/*----------------------------------------------------------*/

always@(posedge clk) begin
    if(index_state_rr == STA_INDEX_AUDIO_INDEX) begin

        if(index_state_change_flag) begin
            type_audio_index_cnt <= 8'd0;
        end
        else if(read_dv_r && read_cnt_r[3:0] == 4'd0 && read_data_r == 8'd2) begin
            type_audio_index_cnt <= type_audio_index_cnt + 1'b1;
        end

        if(read_dv_r && read_cnt_r[3:0] == 4'd15) begin
            type_audio_hold <= 1'b0;
        end
        else if(read_dv_r && read_cnt_r[3:0] == 4'd0 && read_data_r == 8'd2) begin
            type_audio_hold <= 1'b1;
        end

        if(read_dv_r && (read_cnt_r[3:0] >= 4'd1 && read_cnt_r[3:0] <= 4'd3)) begin
            type_audio_saddr <= {read_data_r,type_audio_saddr[23:8]};
        end

        if(read_dv_r && (read_cnt_r[3:0] >= 4'd4 && read_cnt_r[3:0] <= 4'd7)) begin
            type_audio_blength <= {read_data_r,type_audio_blength[31:8]};
        end

        if(read_dv_r && (read_cnt_r[3:0] >= 4'd8 && read_cnt_r[3:0] <= 4'd11)) begin
            type_audio_sampling_freq <= {read_data_r,type_audio_sampling_freq[31:8]};
        end

        if(read_dv_r && (read_cnt_r[3:0] >= 4'd12 && read_cnt_r[3:0] <= 4'd13)) begin
            type_audio_channel_nub <= {read_data_r,type_audio_channel_nub[15:8]};
        end

        if(read_dv_r && (read_cnt_r[3:0] >= 4'd14 && read_cnt_r[3:0] <= 4'd15)) begin
            type_audio_bit_depth <= {read_data_r,type_audio_bit_depth[15:8]};
        end

        type_audio_save_flag <= read_dv_r && read_cnt_r[3:0] == 4'd15;
    end
    else begin
        type_audio_save_flag <= 1'b0;
    end
end

always@(posedge clk) begin
    if(index_state_rr == STA_INDEX_AUDIO_INDEX) begin
        sd_audio_Structures_flag    <= type_audio_save_flag;
        sd_audio_Structures_data    <= type_audio_save_flag ? {type_audio_saddr,type_audio_blength,type_audio_sampling_freq,type_audio_channel_nub[3:0],type_audio_bit_depth[5:0]} : sd_audio_Structures_data;
    end
    else begin
        sd_audio_Structures_flag    <= 1'b0;
    end
end

always@(posedge clk) begin
    if(index_state_rr == STA_INDEX_AUDIO_INDEX) begin
        sd_audio_Structures_cnt   <= sd_audio_Structures_flag ? sd_audio_Structures_cnt + 1'b1 : sd_audio_Structures_cnt; 
    end
    else begin
        sd_audio_Structures_cnt   <= 4'd0;
    end
end


/*----------------------------------------------------------*/

always@(posedge clk) begin
    if(reset) begin
        index_done <= 1'b0;
    end
    else if(index_start_flag) begin
        index_done <= 1'b0;
    end
    else if(read_end_r && !read_err_r) begin
        index_done <= 1'b1;
    end

end

always@(posedge clk) begin
    index_state_fail_flag <= read_end_r && read_err_r;
end

always@(posedge clk) begin
    sd_index_init_done <= index_done;
end



endmodule
