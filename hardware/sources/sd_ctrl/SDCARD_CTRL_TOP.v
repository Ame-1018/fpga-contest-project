`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Create Date: 2026/10/08 09:21:17
// Design Name: 
// Module Name: SDCARD_CTRL_TOP
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


module SDCARD_CTRL_TOP #(
    parameter                   CLK_FREQ                    = 50_000_000    ,
    parameter                   CLK_SDIO_SPEED_MAX          = 128 / 2       ,
    parameter                   CLK_SDIO_SPEED_MIN          = 4 / 2             
)(
    input   wire                clk                         ,
    input   wire                reset                       ,

    input   wire                SD_INIT_FLAG                ,
    output  wire                SD_SDIO_INIT_DONE           ,
/*----------------------------------------------------------*/
    output  wire                SD_SDIO_CLK                 ,
    inout   wire                SD_SDIO_CMD                 ,
    inout   wire    [3:0]       SD_SDIO_DATA                ,
/*----------------------------------------------------------*/
    input   wire                SD_USER_RD_REQ              ,
    input   wire    [31:0]      SD_USER_RD_ADDR             ,
    output  wire                SD_USER_RD_ACK              ,

    output  wire                SD_USER_RD_START            ,
    output  wire                SD_USER_RD_DV               ,
    output  wire    [7:0]       SD_USER_RD_DATA             ,
    output  wire                SD_USER_RD_END              ,
    output  wire    [8:0]       SD_USER_RD_CNT              ,
    output  wire                SD_USER_RD_ERR              ,
/*----------------------------------------------------------*/
    input   wire                SD_USER_WR_REQ              ,
    input   wire    [31:0]      SD_USER_WR_ADDR             ,
    output  wire                SD_USER_WR_ACK              ,

    input   wire                SD_USER_WR_DV               ,
    input   wire    [7:0]       SD_USER_WR_DATA             ,
    output  wire                SD_USER_WR_END              ,
    output  wire                SD_USER_WR_ERR              
/*----------------------------------------------------------*/
);

reg     [7:0]                   sd_sdio_clk_max_div_cnt     = 0;
reg                             sd_sdio_clk_max_div_flag    = 0;

reg     [7:0]                   sd_sdio_clk_min_div_cnt     = 0;
reg                             sd_sdio_clk_min_div_flag    = 0;

reg                             sd_sdio_clk                 = 0;

wire                            sd_init_req                 ;
wire                            sd_init_done                ;
wire                            sd_init_clk_done            ;

wire                            sd_init_tx_nrp_req          ;
wire                            sd_init_tx_rp_req           ;
wire    [5:0]                   sd_init_tx_nub              ;
wire    [31:0]                  sd_init_tx_data             ;
wire                            sd_init_tx_ack              ;
wire                            sd_init_tx_end              ;

wire                            sd_init_rp_ack              ;
wire    [2:0]                   sd_init_rp_type             ;
wire    [31:0]                  sd_init_rp_data_Rx          ;
wire    [119:0]                 sd_init_rp_data_R2          ;
wire                            sd_init_rp_err              ;
wire                            sd_init_rp_timeout          ;
/*----------------------------------------------------------*/
wire                            sd_write_data_req           ;
wire                            sd_write_dv                 ;
wire    [7:0]                   sd_write_data               ;
wire                            sd_write_end                ;

wire                            sd_read_start               ;
wire                            sd_read_dv                  ;
wire    [7:0]                   sd_read_data                ;
wire                            sd_read_end                 ;
wire    [8:0]                   sd_read_cnt                 ;
wire    [3:0]                   sd_read_crc_err             ;

wire                            sd_wr_tx_rp_req             ;
wire    [5:0]                   sd_wr_tx_nub                ;
wire    [31:0]                  sd_wr_tx_data               ;
wire                            sd_wr_tx_ack                ;
wire                            sd_wr_tx_end                ;

wire                            sd_wr_rp_ack                ;
wire    [2:0]                   sd_wr_rp_type               ;
wire    [31:0]                  sd_wr_rp_data_Rx            ;
wire                            sd_wr_rp_err                ;
wire                            sd_wr_rp_timeout            ;
/*----------------------------------------------------------*/
wire                            sd_cmd_tx_req               ;
wire                            sd_cmd_tx_rp_req            ;
wire    [5:0]                   sd_cmd_tx_nub               ;
wire    [31:0]                  sd_cmd_tx_data              ;
wire                            sd_cmd_tx_ack               ;
wire                            sd_cmd_tx_end               ;

wire                            sd_cmd_rp_ack               ;
wire    [2:0]                   sd_cmd_rp_type              ;
wire    [31:0]                  sd_cmd_rp_data_Rx           ;
wire    [31:0]                  sd_cmd_rp_data_R2           ;
wire                            sd_cmd_rp_err               ;
wire                            sd_cmd_rp_timeout           ;

/*----------------------------------------------------------*/

always@(posedge clk) begin
    if(sd_sdio_clk_max_div_cnt == CLK_SDIO_SPEED_MAX - 1'b1) begin
        sd_sdio_clk_max_div_cnt <= 8'd0;
    end
    else begin
        sd_sdio_clk_max_div_cnt <= sd_sdio_clk_max_div_cnt + 1'b1;
    end

    sd_sdio_clk_max_div_flag <= sd_sdio_clk_max_div_cnt == CLK_SDIO_SPEED_MAX - 1'b1 ? 1'b1 : 1'b0;
end

always@(posedge clk) begin
    if(sd_sdio_clk_min_div_cnt == CLK_SDIO_SPEED_MIN - 1'b1) begin
        sd_sdio_clk_min_div_cnt <= 8'd0;
    end
    else begin
        sd_sdio_clk_min_div_cnt <= sd_sdio_clk_min_div_cnt + 1'b1;
    end

    sd_sdio_clk_min_div_flag <= sd_sdio_clk_min_div_cnt == CLK_SDIO_SPEED_MIN - 1'b1 ? 1'b1 : 1'b0;
end

always@(posedge clk) begin
    if(sd_init_clk_done == 1'b0 && sd_sdio_clk_max_div_flag) begin
        sd_sdio_clk <= ~sd_sdio_clk;
    end
    // else if(sd_init_clk_done == 1'b1 && sd_sdio_clk_min_div_flag) begin
    //     sd_sdio_clk <= ~sd_sdio_clk;
    // end
    else if(sd_init_clk_done == 1'b1) begin
        sd_sdio_clk <= ~sd_sdio_clk;
    end
end

/*----------------------------------------------------------*/

SD_WR_CTRL SD_WR_CTRL(
    .clk                        (clk                        ),
    .reset                      (reset                      ),

    .sd_init_done               (sd_init_done               ),
/*----------------------------------------------------------*/
    .sd_user_w_req              (SD_USER_WR_REQ             ),
    .sd_user_w_addr             (SD_USER_WR_ADDR            ),
    .sd_user_w_ack              (SD_USER_WR_ACK             ),

    .sd_user_w_dv               (SD_USER_WR_DV              ),
    .sd_user_w_data             (SD_USER_WR_DATA            ),
    .sd_user_w_end              (SD_USER_WR_END             ),
    .sd_user_w_err              (SD_USER_WR_ERR             ),
/*----------------------------------------------------------*/
    .sd_user_r_req              (SD_USER_RD_REQ             ),
    .sd_user_r_addr             (SD_USER_RD_ADDR            ),
    .sd_user_r_ack              (SD_USER_RD_ACK             ),

    .sd_user_r_start            (SD_USER_RD_START           ),
    .sd_user_r_dv               (SD_USER_RD_DV              ),
    .sd_user_r_data             (SD_USER_RD_DATA            ),
    .sd_user_r_end              (SD_USER_RD_END             ),
    .sd_user_r_cnt              (SD_USER_RD_CNT             ),
    .sd_user_r_err              (SD_USER_RD_ERR             ),
/*----------------------------------------------------------*/
    .sd_write_data_req          (sd_write_data_req          ),
    .sd_write_dv                (sd_write_dv                ),
    .sd_write_data              (sd_write_data              ),
    .sd_write_end               (sd_write_end               ),

    .sd_read_start              (sd_read_start              ),
    .sd_read_dv                 (sd_read_dv                 ),
    .sd_read_data               (sd_read_data               ),
    .sd_read_end                (sd_read_end                ),
    .sd_read_cnt                (sd_read_cnt                ),
    .sd_read_crc_err            (sd_read_crc_err            ),
/*----------------------------------------------------------*/
    .sd_sdio_clk                (sd_sdio_clk                ),

    .sd_wr_tx_rp_req            (sd_wr_tx_rp_req            ),
    .sd_wr_tx_nub               (sd_wr_tx_nub               ),
    .sd_wr_tx_data              (sd_wr_tx_data              ),
    .sd_wr_tx_ack               (sd_wr_tx_ack               ),
    .sd_wr_tx_end               (sd_wr_tx_end               ),

    .sd_wr_rp_ack               (sd_wr_rp_ack               ),
    .sd_wr_rp_type              (sd_wr_rp_type              ),
    .sd_wr_rp_data_Rx           (sd_wr_rp_data_Rx           ),
    .sd_wr_rp_err               (sd_wr_rp_err               ),
    .sd_wr_rp_timeout           (sd_wr_rp_timeout           )
);

/*----------------------------------------------------------*/

assign sd_cmd_tx_nrp_req    = sd_init_done  ? 1'b0              : sd_init_tx_nrp_req    ;
assign sd_cmd_tx_rp_req     = sd_init_done  ? sd_wr_tx_rp_req   : sd_init_tx_rp_req     ;
assign sd_cmd_tx_nub        = sd_init_done  ? sd_wr_tx_nub      : sd_init_tx_nub        ;
assign sd_cmd_tx_data       = sd_init_done  ? sd_wr_tx_data     : sd_init_tx_data       ;

assign sd_init_tx_ack       = sd_init_done  ? 1'b0              : sd_cmd_tx_ack         ;
assign sd_init_tx_end       = sd_init_done  ? 1'b0              : sd_cmd_tx_end         ;

assign sd_wr_tx_ack         = sd_init_done  ? sd_cmd_tx_ack     : 1'b0                  ;
assign sd_wr_tx_end         = sd_init_done  ? sd_cmd_tx_end     : 1'b0                  ;

assign sd_init_rp_ack       = sd_init_done  ? 1'b0              : sd_cmd_rp_ack         ;
assign sd_init_rp_type      = sd_init_done  ? 3'd0              : sd_cmd_rp_type        ;
assign sd_init_rp_data_Rx   = sd_init_done  ? 32'h0             : sd_cmd_rp_data_Rx     ;
assign sd_init_rp_data_R2   = sd_init_done  ? 120'h0            : sd_cmd_rp_data_R2     ;
assign sd_init_rp_err       = sd_init_done  ? 1'b0              : sd_cmd_rp_err         ;
assign sd_init_rp_timeout   = sd_init_done  ? 1'b0              : sd_cmd_rp_timeout     ;

assign sd_wr_rp_ack         = sd_init_done  ? sd_cmd_rp_ack     : 1'b0                  ;
assign sd_wr_rp_type        = sd_init_done  ? sd_cmd_rp_type    : 3'd0                  ;
assign sd_wr_rp_data_Rx     = sd_init_done  ? sd_cmd_rp_data_Rx : 32'h0                 ;
assign sd_wr_rp_err         = sd_init_done  ? sd_cmd_rp_err     : 1'b0                  ;
assign sd_wr_rp_timeout     = sd_init_done  ? sd_cmd_rp_timeout : 1'b0                  ;

/*----------------------------------------------------------*/

SD_INTERFACE_CTRL SD_INTERFACE_CTRL(
    .clk                        (clk                        ),
    .reset                      (reset                      ),

    .sd_sdio_clk                (sd_sdio_clk                ),

    .sd_cmd_tx_nrp_req          (sd_cmd_tx_nrp_req          ),//no responding
    .sd_cmd_tx_rp_req           (sd_cmd_tx_rp_req           ),//   responding
    .sd_cmd_tx_nub              (sd_cmd_tx_nub              ),
    .sd_cmd_tx_data             (sd_cmd_tx_data             ),
    .sd_cmd_tx_ack              (sd_cmd_tx_ack              ),
    .sd_cmd_tx_end              (sd_cmd_tx_end              ),

    .sd_cmd_rp_ack              (sd_cmd_rp_ack              ),
    .sd_cmd_rp_type             (sd_cmd_rp_type             ),
    .sd_cmd_rp_data_Rx          (sd_cmd_rp_data_Rx          ),
    .sd_cmd_rp_data_R2          (sd_cmd_rp_data_R2          ),
    .sd_cmd_rp_err              (sd_cmd_rp_err              ),
    .sd_cmd_rp_timeout          (sd_cmd_rp_timeout          ),
/*----------------------------------------------------------*/
    .sd_write_data_req          (sd_write_data_req          ),
    .sd_write_dv                (sd_write_dv                ),
    .sd_write_data              (sd_write_data              ),
    .sd_write_end               (sd_write_end               ),

    .sd_read_start              (sd_read_start              ),
    .sd_read_dv                 (sd_read_dv                 ),
    .sd_read_data               (sd_read_data               ),
    .sd_read_end                (sd_read_end                ),
    .sd_read_cnt                (sd_read_cnt                ),
    .sd_read_crc_err            (sd_read_crc_err            ),
/*----------------------------------------------------------*/
    .SD_SDIO_CLK                (SD_SDIO_CLK                ),
    .SD_SDIO_CMD                (SD_SDIO_CMD                ),
    .SD_SDIO_DATA               (SD_SDIO_DATA               )
);

/*----------------------------------------------------------*/


SD_INIT_CTRL #(
    .CLK_FREQ                   (CLK_FREQ                   )
)SD_INIT_CTRL(
    .clk                        (clk                        ),
    .reset                      (reset                      ),
    
    .sd_sdio_clk                (sd_sdio_clk                ),

    .sd_init_req                (sd_init_req                ),
    .sd_init_done               (sd_init_done               ),
    .sd_init_clk_done           (sd_init_clk_done           ),

    .sd_init_tx_nrp_req         (sd_init_tx_nrp_req         ),//no responding
    .sd_init_tx_rp_req          (sd_init_tx_rp_req          ),//   responding
    .sd_init_tx_nub             (sd_init_tx_nub             ),
    .sd_init_tx_data            (sd_init_tx_data            ),
    .sd_init_tx_ack             (sd_init_tx_ack             ),
    .sd_init_tx_end             (sd_init_tx_end             ),

    .sd_init_rp_ack             (sd_init_rp_ack             ),
    .sd_init_rp_type            (sd_init_rp_type            ),
    .sd_init_rp_data_Rx         (sd_init_rp_data_Rx         ),
    .sd_init_rp_data_R2         (sd_init_rp_data_R2         ),
    .sd_init_rp_err             (sd_init_rp_err             ),
    .sd_init_rp_timeout         (sd_init_rp_timeout         )
);

assign SD_SDIO_INIT_DONE        = sd_init_done              ;
assign sd_init_req              = SD_INIT_FLAG              ;

/*----------------------------------------------------------*/

endmodule
