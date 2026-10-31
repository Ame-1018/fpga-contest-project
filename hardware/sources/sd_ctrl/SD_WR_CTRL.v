`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Create Date: 2026/10/08 09:21:17 
// Module Name: SD_WR_CTRL
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


module SD_WR_CTRL(
    input   wire                clk                         ,
    input   wire                reset                       ,

    input   wire                sd_init_done                ,

    input   wire                sd_user_wr_clr              ,
/*----------------------------------------------------------*/
    input   wire                sd_user_w_req               ,
    input   wire    [31:0]      sd_user_w_addr              ,
    output  reg                 sd_user_w_ack               ,
    
    input   wire                sd_user_w_dv                ,
    input   wire    [7:0]       sd_user_w_data              ,
    output  reg                 sd_user_w_end               ,
    output  reg                 sd_user_w_err               ,
/*----------------------------------------------------------*/
    input   wire                sd_user_r_req               ,
    input   wire    [31:0]      sd_user_r_addr              ,
    output  reg                 sd_user_r_ack               ,

    output  reg                 sd_user_r_start             ,
    output  reg                 sd_user_r_dv                ,
    output  reg     [7:0]       sd_user_r_data              ,
    output  reg                 sd_user_r_end               ,
    output  reg     [8:0]       sd_user_r_cnt               ,
    output  reg                 sd_user_r_err               ,
/*----------------------------------------------------------*/

    input   wire                sd_write_data_req           ,
    output  wire                sd_write_dv                 ,
    output  wire    [7:0]       sd_write_data               ,
    input   wire                sd_write_end                ,
/*----------------------------------------------------------*/
    input   wire                sd_read_start               ,
    input   wire                sd_read_dv                  ,
    input   wire    [7:0]       sd_read_data                ,
    input   wire                sd_read_end                 ,
    input   wire    [8:0]       sd_read_cnt                 ,
    input   wire    [3:0]       sd_read_crc_err             ,

    input   wire                sd_sdio_clk                 ,

    output  reg                 sd_wr_tx_rp_req             ,
    output  reg     [5:0]       sd_wr_tx_nub                ,
    output  reg     [31:0]      sd_wr_tx_data               ,
    input   wire                sd_wr_tx_ack                ,
    input   wire                sd_wr_tx_end                ,

    input   wire                sd_wr_rp_ack                ,
    input   wire    [2:0]       sd_wr_rp_type               ,
    input   wire    [31:0]      sd_wr_rp_data_Rx            ,
    input   wire                sd_wr_rp_err                ,
    input   wire                sd_wr_rp_timeout            
);

parameter                       STA_IDLE                    = 3'd0  ,
                                STA_WRITE                   = 3'd1  ,
                                STA_READ                    = 3'd2  ,
                                STA_DELAY                   = 3'd3  ,
                                STA_FAIL                    = 3'd4  ;

localparam                      SD_WR_DELAY_CNT             = 64 - 1;

reg     [2:0]                   sd_wr_state                 ;
reg     [2:0]                   sd_wr_state_r               ;
reg     [2:0]                   sd_wr_state_rr              ;

reg                             sd_wr_state_change_flag     ;

reg                             sd_sdio_clk_r               ;
reg                             sd_sdio_clk_rr              ;
wire                            sd_sdio_clk_pos             ;

reg     [7:0]                   sd_wr_delay_cnt             ;
reg                             sd_wr_delay_flag            ;

reg                             sd_wr_fail_flag             ;


/*----------------------------------------------------------*/

always@(posedge clk) begin
    if(reset) begin
        sd_wr_state <= STA_IDLE;
    end
    else if(sd_wr_fail_flag) begin
        sd_wr_state <= STA_FAIL;
    end
    else begin
        case(sd_wr_state)
            STA_IDLE    :  begin 
                if(sd_user_r_req) begin
                    sd_wr_state <= STA_READ;
                end 
                else if(sd_user_w_req) begin
                    sd_wr_state <= STA_WRITE;
                end
            end
            STA_WRITE   :  begin if(sd_user_w_end)      begin sd_wr_state <= STA_DELAY  ;end end
            STA_READ    :  begin if(sd_user_r_end)      begin sd_wr_state <= STA_DELAY  ;end end
            STA_DELAY   :  begin if(sd_wr_delay_flag)   begin sd_wr_state <= STA_IDLE   ;end end
            STA_FAIL    :  begin if(sd_user_wr_clr)     begin sd_wr_state <= STA_IDLE   ;end end
            default     :  begin                              sd_wr_state <= STA_IDLE   ;end
        endcase
    end

    sd_wr_state_r <= sd_wr_state;
    sd_wr_state_rr <= sd_wr_state_r;

    sd_wr_state_change_flag <= sd_wr_state_rr != sd_wr_state_r;
end

always@(posedge clk) begin
    if(sd_wr_state == STA_READ && sd_read_end && sd_read_crc_err != 4'h0) begin
        sd_wr_fail_flag <= 1'b1;
    end
    else begin
        sd_wr_fail_flag <= 1'b0;
    end
end




always@(posedge clk) begin
    sd_sdio_clk_r <= sd_sdio_clk;
    sd_sdio_clk_rr <= sd_sdio_clk_r;
end

assign sd_sdio_clk_pos = sd_sdio_clk_r & !sd_sdio_clk_rr;

always@(posedge clk) begin
    if(reset) begin
        sd_wr_delay_cnt <= 8'd0;
    end
    else if(sd_wr_state == STA_DELAY && sd_sdio_clk_pos) begin
        sd_wr_delay_cnt <= sd_wr_delay_cnt + 1'b1;
    end
    else if(sd_wr_state != STA_DELAY) begin
        sd_wr_delay_cnt <= 8'd0;
    end

    sd_wr_delay_flag <= sd_wr_delay_cnt == SD_WR_DELAY_CNT && sd_sdio_clk_pos ? 1'b1 : 1'b0;
end


/*----------------------------------------------------------*/
    // input   wire                sd_user_w_req               ,
    // input   wire    [31:0]      sd_user_w_addr              ,
    // input   wire                sd_user_w_dv                ,
    // input   wire    [7:0]       sd_user_w_data              ,
    // output  reg                 sd_user_w_ack               ,
    // output  reg                 sd_user_w_end               ,


always@(posedge clk) begin
    if(sd_user_w_req && sd_wr_state == STA_WRITE && !sd_user_w_ack) begin
        sd_user_w_ack <= 1'b1;
    end
    else begin
        sd_user_w_ack <= 1'b0;
    end
end






/*----------------------------------------------------------*/


always@(posedge clk) begin
    sd_user_r_ack <= sd_user_r_req && sd_wr_state == STA_READ && !sd_user_r_ack ? 1'b1 : 1'b0;
end

always@(posedge clk) begin
    if(sd_wr_state == STA_READ && sd_read_dv) begin
        sd_user_r_dv    <= 1'b1;
        sd_user_r_data  <= sd_read_data;
    end
    else begin
        sd_user_r_dv <= 1'b0;
    end
end

always@(posedge clk) begin
    if(sd_wr_state == STA_READ) begin
        sd_user_r_cnt <= sd_read_dv ? sd_read_cnt : sd_user_r_cnt;
    end
    else begin
        sd_user_r_cnt <= 9'd0;
    end
end

always@(posedge clk) begin
    sd_user_r_end   <= sd_wr_state == STA_READ && sd_read_end   ? 1'b1 : 1'b0;
    sd_user_r_start <= sd_wr_state == STA_READ && sd_read_start ? 1'b1 : 1'b0;
end

always@(posedge clk) begin
    if(reset) begin
        sd_user_r_err <= 1'b0;
    end
    else if(sd_user_wr_clr) begin
        sd_user_r_err <= 1'b0;
    end
    else if(sd_wr_state == STA_READ && sd_read_end && sd_read_crc_err != 4'h0) begin
        sd_user_r_err <= 1'b1;
    end
end


/*----------------------------------------------------------*/

always@(posedge clk) begin
    if(reset) begin
        sd_wr_tx_nub    <= 6'd0;
        sd_wr_tx_data   <= 32'd0;
    end
    else if(sd_wr_state_change_flag) begin
        case(sd_wr_state_rr)   
            STA_WRITE   : begin sd_wr_tx_nub <= 6'd24 ;sd_wr_tx_data <= sd_user_w_addr  ;end
            STA_READ    : begin sd_wr_tx_nub <= 6'd17 ;sd_wr_tx_data <= sd_user_r_addr  ;end
            default     : begin sd_wr_tx_nub <= 6'd0  ;sd_wr_tx_data <= 32'h0           ;end
        endcase
    end
end

always@(posedge clk) begin
    if(reset) begin
        sd_wr_tx_rp_req <= 1'b0;
    end
    else if(sd_wr_state_change_flag && (sd_wr_state_rr == STA_WRITE || sd_wr_state_rr == STA_READ)) begin
        sd_wr_tx_rp_req <= 1'b1;
    end
    else if(sd_wr_tx_ack) begin
        sd_wr_tx_rp_req <= 1'b0;
    end
end


endmodule
