`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Create Date: 2026/10/08 09:21:17
// Module Name: EG4_SD_HDMI_SUBSYSTOP
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
`include "../eg4_sdram_enc/global_def.v"

module EG4_SD_HDMI_SUBSYSTOP #(
    parameter                   SD_SYS_CLK_FREQ = 50_000_000    ,
    parameter                   SDRAM_CLK_FREQ  = 150_000_000   ,
    // 改这一处即可切换 HDMI 时序。字符串按 128 bit 右侧对齐，最长 16 个字符。
    // 可选：
    //   "640x480@60"    VIC 1   像素时钟 25.175 MHz
    //   "1280x720@60"   VIC 4   像素时钟 74.25 MHz
    //   "1920x1080@30"  VIC 34  像素时钟 74.25 MHz
    //   "1920x1080@60"  VIC 16  像素时钟 148.5 MHz
    // 时序取自 CTA-861，1080p60 与 APUG092 表 2-1 默认值一致。
    // 本参数不改 SYS_PLL。像素时钟仍须单独配成上表频率，串行时钟为像素时钟的 5 倍。
    parameter [127:0]           HDMI_VIDEO_MODE = "1280x720@60"
)(
    input   wire                sys_clk                     ,

    input   wire    [3:0]       KEY_INDEPENDENT             ,//(*mark_debug = "true"*)
    input   wire    [3:0]       KEY_SWITCH                  ,//(*mark_debug = "true"*)

    input   wire                UART_RXD                    ,
    output  wire                UART_TXD                    ,

    output  wire                SD_SDIO_CLK                 ,
    inout   wire                SD_SDIO_CMD                 ,
    inout   wire    [3:0]       SD_SDIO_DATA                ,

    output  wire    [5:0]       PROBE_SD_MON                ,

    output  wire    [3:0]       SYS_LED                     ,

    output  wire                HDMIB_CLK_P                 ,
    output  wire                HDMIB_D2_P                  ,
    output  wire                HDMIB_D1_P                  ,
    output  wire                HDMIB_D0_P                  ,

    output  wire                HDMIB_DDC_SCL               ,
    inout   wire                HDMIB_DDC_SDA               
);


assign PROBE_SD_MON[0] = SD_SDIO_CLK        ;   //GPIOA9
assign PROBE_SD_MON[1] = SD_SDIO_CMD        ;   //GPIOA6
assign PROBE_SD_MON[2] = SD_SDIO_DATA[0]    ;   //GPIOA8
assign PROBE_SD_MON[3] = SD_SDIO_DATA[1]    ;   //GPIOA7
assign PROBE_SD_MON[4] = SD_SDIO_DATA[2]    ;   //GPIOA0
assign PROBE_SD_MON[5] = SD_SDIO_DATA[3]    ;   //GPIOA16

localparam [127:0] HDMI_MODE_640x480_60   = "640x480@60";
localparam [127:0] HDMI_MODE_1280x720_60  = "1280x720@60";
localparam [127:0] HDMI_MODE_1920x1080_30 = "1920x1080@30";
localparam [127:0] HDMI_MODE_1920x1080_60 = "1920x1080@60";

localparam integer HDMI_HTOTAL =
    (HDMI_VIDEO_MODE == HDMI_MODE_640x480_60)   ? 800  :
    (HDMI_VIDEO_MODE == HDMI_MODE_1280x720_60)  ? 1650 :
    (HDMI_VIDEO_MODE == HDMI_MODE_1920x1080_30) ? 2200 :
    (HDMI_VIDEO_MODE == HDMI_MODE_1920x1080_60) ? 2200 : 0;
localparam integer HDMI_HSA =
    (HDMI_VIDEO_MODE == HDMI_MODE_640x480_60)   ? 96 :
    (HDMI_VIDEO_MODE == HDMI_MODE_1280x720_60)  ? 40 :
    (HDMI_VIDEO_MODE == HDMI_MODE_1920x1080_30) ? 44 :
    (HDMI_VIDEO_MODE == HDMI_MODE_1920x1080_60) ? 44 : 0;
localparam integer HDMI_HFP =
    (HDMI_VIDEO_MODE == HDMI_MODE_640x480_60)   ? 16  :
    (HDMI_VIDEO_MODE == HDMI_MODE_1280x720_60)  ? 110 :
    (HDMI_VIDEO_MODE == HDMI_MODE_1920x1080_30) ? 88  :
    (HDMI_VIDEO_MODE == HDMI_MODE_1920x1080_60) ? 88  : 0;
localparam integer HDMI_HBP =
    (HDMI_VIDEO_MODE == HDMI_MODE_640x480_60)   ? 48  :
    (HDMI_VIDEO_MODE == HDMI_MODE_1280x720_60)  ? 220 :
    (HDMI_VIDEO_MODE == HDMI_MODE_1920x1080_30) ? 148 :
    (HDMI_VIDEO_MODE == HDMI_MODE_1920x1080_60) ? 148 : 0;
localparam integer HDMI_HACTIVE =
    (HDMI_VIDEO_MODE == HDMI_MODE_640x480_60)   ? 640  :
    (HDMI_VIDEO_MODE == HDMI_MODE_1280x720_60)  ? 1280 :
    (HDMI_VIDEO_MODE == HDMI_MODE_1920x1080_30) ? 1920 :
    (HDMI_VIDEO_MODE == HDMI_MODE_1920x1080_60) ? 1920 : 0;
localparam integer HDMI_VTOTAL =
    (HDMI_VIDEO_MODE == HDMI_MODE_640x480_60)   ? 525  :
    (HDMI_VIDEO_MODE == HDMI_MODE_1280x720_60)  ? 750  :
    (HDMI_VIDEO_MODE == HDMI_MODE_1920x1080_30) ? 1125 :
    (HDMI_VIDEO_MODE == HDMI_MODE_1920x1080_60) ? 1125 : 0;
localparam integer HDMI_VSA =
    (HDMI_VIDEO_MODE == HDMI_MODE_640x480_60)   ? 2 :
    (HDMI_VIDEO_MODE == HDMI_MODE_1280x720_60)  ? 5 :
    (HDMI_VIDEO_MODE == HDMI_MODE_1920x1080_30) ? 5 :
    (HDMI_VIDEO_MODE == HDMI_MODE_1920x1080_60) ? 5 : 0;
localparam integer HDMI_VFP =
    (HDMI_VIDEO_MODE == HDMI_MODE_640x480_60)   ? 10 :
    (HDMI_VIDEO_MODE == HDMI_MODE_1280x720_60)  ? 5  :
    (HDMI_VIDEO_MODE == HDMI_MODE_1920x1080_30) ? 4  :
    (HDMI_VIDEO_MODE == HDMI_MODE_1920x1080_60) ? 4  : 0;
localparam integer HDMI_VBP =
    (HDMI_VIDEO_MODE == HDMI_MODE_640x480_60)   ? 33 :
    (HDMI_VIDEO_MODE == HDMI_MODE_1280x720_60)  ? 20 :
    (HDMI_VIDEO_MODE == HDMI_MODE_1920x1080_30) ? 36 :
    (HDMI_VIDEO_MODE == HDMI_MODE_1920x1080_60) ? 36 : 0;
localparam integer HDMI_VACTIVE =
    (HDMI_VIDEO_MODE == HDMI_MODE_640x480_60)   ? 480  :
    (HDMI_VIDEO_MODE == HDMI_MODE_1280x720_60)  ? 720  :
    (HDMI_VIDEO_MODE == HDMI_MODE_1920x1080_30) ? 1080 :
    (HDMI_VIDEO_MODE == HDMI_MODE_1920x1080_60) ? 1080 : 0;
localparam integer HDMI_VIDEO_VIC =
    (HDMI_VIDEO_MODE == HDMI_MODE_640x480_60)   ? 1  :
    (HDMI_VIDEO_MODE == HDMI_MODE_1280x720_60)  ? 4  :
    (HDMI_VIDEO_MODE == HDMI_MODE_1920x1080_30) ? 34 :
    (HDMI_VIDEO_MODE == HDMI_MODE_1920x1080_60) ? 16 : 0;

// 单位 kHz。只作对照，不接入 PLL。
localparam integer HDMI_PIXEL_CLK_KHZ =
    (HDMI_VIDEO_MODE == HDMI_MODE_640x480_60)   ? 25175  :
    (HDMI_VIDEO_MODE == HDMI_MODE_1280x720_60)  ? 74250  :
    (HDMI_VIDEO_MODE == HDMI_MODE_1920x1080_30) ? 74250  :
    (HDMI_VIDEO_MODE == HDMI_MODE_1920x1080_60) ? 148500 : 0;

reg     [15:0]                  sys_pll_reset_cnt           = 0;
reg                             sys_pll_reset               = 0;

wire                            SYSCLK_50M                  ;
wire                            SYSCLK_150M                 ;
wire                            SYSCLK_150M_S180            ;
wire                            SYSCLK_75M                  ;
wire                            SYSCLK_375M                 ;
wire                            SYSCLK_LOCKED               ;//   (*mark_debug = "true"*)
wire                            SYSRESET                    ;

wire    [2:0]                   KEY_INDEPENDENT_FLAG        ;
wire    [3:0]                   key_sw_level                ;
wire                            key_nav_right               ;
wire                            key_nav_ok                  ;
wire                            key_nav_left                ;
wire                            key_pic_tog                 ;
wire                            key_audio_next              ;
wire                            key_bmp_init                ;
reg                             key_pic_s1                  ;
reg                             key_pic_s2                  ;
reg                             key_pic_s3                  ;
wire                            key_pic_pulse               ;

assign key_pic_pulse            = key_pic_s2 ^ key_pic_s3   ;
assign KEY_INDEPENDENT_FLAG[0]  = 1'b0                      ;
assign KEY_INDEPENDENT_FLAG[1]  = key_bmp_init              ;
assign KEY_INDEPENDENT_FLAG[2]  = 1'b0                      ;

key_board #(
    .CLK_FREQ                   (SD_SYS_CLK_FREQ            )
)key_board(
    .clk                        (SYSCLK_50M                 ),
    .reset                      (SYSRESET                   ),
    .key_in                     (KEY_INDEPENDENT            ),
    .sw_in                      (KEY_SWITCH                 ),
    .sw_level                   (key_sw_level               ),
    .nav_right                  (key_nav_right              ),
    .nav_ok                     (key_nav_ok                 ),
    .nav_left                   (key_nav_left               ),
    .pic_tog                    (key_pic_tog                ),
    .audio_next_pulse           (key_audio_next             ),
    .bmp_init_pulse             (key_bmp_init               )
);

always @(posedge SYSCLK_150M) begin
    if(SYSRESET) begin
        key_pic_s1 <= 1'b0;
        key_pic_s2 <= 1'b0;
        key_pic_s3 <= 1'b0;
    end
    else begin
        key_pic_s1 <= key_pic_tog;
        key_pic_s2 <= key_pic_s1;
        key_pic_s3 <= key_pic_s2;
    end
end

/*----------------------------------------------------------*/
wire                            SD_INIT_FLAG                ;
wire                            SD_SDIO_INIT_DONE           ;

wire                            SD_USER_RD_REQ              ;
wire    [31:0]                  SD_USER_RD_ADDR             ;
wire                            SD_USER_RD_ACK              ;
wire                            SD_USER_RD_START            ;
wire                            SD_USER_RD_DV               ;
wire    [7:0]                   SD_USER_RD_DATA             ;
wire                            SD_USER_RD_END              ;
wire    [8:0]                   SD_USER_RD_CNT              ;
wire                            SD_USER_RD_ERR              ;

wire                            SD_USER_WR_REQ              ;
wire    [31:0]                  SD_USER_WR_ADDR             ;
wire                            SD_USER_WR_ACK              ;
wire                            SD_USER_WR_DV               ;
wire    [7:0]                   SD_USER_WR_DATA             ;
wire                            SD_USER_WR_END              ;
wire                            SD_USER_WR_ERR              ;

/*----------------------------------------------------------*/
wire                            SD_INDEX_INIT_FLAG          ;
wire                            SD_INDEX_INIT_DONE          ;

wire                            SD_INDEX_R_REQ              ;
wire    [31:0]                  SD_INDEX_R_ADDR             ;
wire                            SD_INDEX_R_ACK              ;
wire                            SD_INDEX_R_START            ;
wire                            SD_INDEX_R_DV               ;
wire    [7:0]                   SD_INDEX_R_DATA             ;
wire                            SD_INDEX_R_END              ;
wire    [8:0]                   SD_INDEX_R_CNT              ;
wire                            SD_INDEX_R_ERR              ;

wire                            SD_BMP_STRUSTURES_FLAG      ;
wire    [3:0]                   SD_BMP_STRUSTURES_CNT       ;
wire    [81:0]                  SD_BMP_STRUSTURES_DATA      ;//24+32+13+13

wire                            SD_AUDIO_STRUSTURES_FLAG    ;
wire    [3:0]                   SD_AUDIO_STRUSTURES_CNT     ;
wire    [97:0]                  SD_AUDIO_STRUSTURES_DATA    ;//24+32+32+4+6

/*----------------------------------------------------------*/

wire                            SD_BMP_INIT_FLAG            ;
wire                            SD_BMP_INIT_DONE            ;

wire                            SD_BMP_R_REQ                ;
wire    [31:0]                  SD_BMP_R_ADDR               ;
wire                            SD_BMP_R_ACK                ;
wire                            SD_BMP_R_START              ;
wire                            SD_BMP_R_DV                 ;
wire    [7:0]                   SD_BMP_R_DATA               ;
wire                            SD_BMP_R_END                ;
wire    [8:0]                   SD_BMP_R_CNT                ;
wire                            SD_BMP_R_ERR                ;

wire                            SD_AUDIO_R_REQ              ;
wire    [31:0]                  SD_AUDIO_R_ADDR             ;
wire                            SD_AUDIO_R_ACK              ;
wire                            SD_AUDIO_R_START            ;
wire                            SD_AUDIO_R_DV               ;
wire    [7:0]                   SD_AUDIO_R_DATA             ;
wire                            SD_AUDIO_R_END              ;
wire    [8:0]                   SD_AUDIO_R_CNT              ;
wire                            SD_AUDIO_R_ERR              ;

// 上一首、下一首、循环由外部接入，这里只保留连线。
wire                            SD_AUDIO_PREVIOUS           ;
wire                            SD_AUDIO_NEXT               ;
wire                            SD_AUDIO_LOOP               ;
wire                            ARC_AUDIO_REQ               ;
wire                            ARC_AUDIO_ACK               ;
wire    [47:0]                  ARC_AUDIO_DATA              ;

wire                            SD_BMP_OUT_START            ;
wire    [3:0]                   SD_BMP_OUT_INDEX            ;
wire    [12:0]                  SD_BMP_OUT_WIDTH            ;
wire    [12:0]                  SD_BMP_OUT_HEIGHT           ;
wire                            SD_BMP_OUT_DV               ;
wire    [23:0]                  SD_BMP_OUT_DATA             ;
wire    [12:0]                  SD_BMP_OUT_XCNT             ;
wire    [12:0]                  SD_BMP_OUT_YCNT             ;
/*----------------------------------------------------------*/

wire                            SDRAM_INIT_DONE             ;
wire                            SDRAM_INIT_REF_VAL          ;
wire                            SDRAM_BUSY                  ;

wire                            SDRAM_APP_WR_EN             ;
wire    [20:0]                  SDRAM_APP_WR_ADDR           ;
wire    [3:0]                   SDRAM_APP_WR_DM             ;
wire    [31:0]                  SDRAM_APP_WR_DIN            ;

wire                            SDRAM_APP_RD_EN             ;
wire    [20:0]                  SDRAM_APP_RD_ADDR           ;
wire                            SDRAM_APP_RD_DV             ;
wire    [31:0]                  SDRAM_APP_RD_DATA           ;

/*----------------------------------------------------------*/

wire                            SDRAM_INDEX_CHANGE_AUTO     ;// auto : 1 ; manual : 0;
wire    [7:0]                   SDRAM_INDEX_CHANGE_TIME     ;// auto change frame rate 
wire                            SDRAM_INDEX_CHANGE_FLAG     ;// manual change

wire    [7:0]                   SDRAM_SET_INDEX_MAX         ;// auto change frame rate 

wire                            SDRAM_PICTUREX_CHANGE       ;
wire    [2:0]                   SDRAM_PICTURE1_INDEX        ;
wire    [2:0]                   SDRAM_PICTURE2_INDEX        ;

/*----------------------------------------------------------*/

wire    [2:0]                   SDRAM_ARBIT_REQ             ;
wire    [2:0]                   SDRAM_ARBIT_REQ_END         ;
wire    [2:0]                   SDRAM_ARBIT_ALLOW           ;
wire                            SCALE_REQ                   ;
wire                            SCALE_END                   ;
wire                            SCALE_RUN                   ;
wire                            SCALE_WANT                  ;
wire                            SCALE_PORT                  ;
// 显示始终走这一条行读。关缩放时目标矩形等于源图，转场也不换读口。
assign SCALE_PORT = SCALE_RUN | SCALE_WANT;
wire                            VPU_CUT_ACTIVE              ;
wire                            VPU_CUT_DONE_TOG            ;
wire                            VPU_CUT_DISABLE             ;
wire                            SCALE_FLUSH                 ;
wire                            SCALE_LINE_REQ              ;
wire    [12:0]                  SCALE_LINE_Y                ;
wire    [1:0]                   SCALE_LINE_BANK             ;
wire                            SCALE_LINE_PIC             ;
wire                            SCALE_LINE_ACK              ;
wire                            SCALE_PIX_RE                ;
wire    [23:0]                  SCALE_PIX_DATA              ;
wire                            SCALE_PIX_EMPTY             ;
wire                            SCALE_PIX_VALID             ;

wire                            O_HDMI_HSYNC                ;//(*mark_debug = "true"*)
wire                            O_HDMI_VSYNC                ;//(*mark_debug = "true"*)
wire                            O_HDMI_DE                   ;//(*mark_debug = "true"*)
wire    [12:0]                  O_HDMI_XCNT                 ;//(*mark_debug = "true"*)
wire    [12:0]                  O_HDMI_YCNT                 ;//(*mark_debug = "true"*)
wire    [23:0]                  O_HDMI_RGB1                 ;//(*mark_debug = "true"*)
wire    [23:0]                  O_HDMI_RGB2                 ;//(*mark_debug = "true"*)

// HDMI 1.4b 音频发射相关
wire                            hdmi_audio_pll_lock         ;
wire                            hdmi_audio_mclk             ;
wire                            hdmi_audio_i2s_bclk         ;
wire                            hdmi_audio_i2s_lrck         ;
wire                            hdmi_audio_i2s_dout         ;

wire                            hdmi_audio_valid            ;
wire    [23:0]                  hdmi_audio_left_data        ;
wire    [23:0]                  hdmi_audio_right_data       ;

wire                            hdmi_acr_valid              ;
wire    [19:0]                  hdmi_acr_cts                ;
wire    [19:0]                  hdmi_acr_n                  ;


wire                            hdmi_axis_s_user            ;
wire                            hdmi_axis_s_valid           ;
wire                            hdmi_axis_s_last            ;
wire    [23:0]                  hdmi_axis_s_data            ;
wire                            hdmi_axis_s_ready           ;

wire                            hdmi_video_locked           ;

wire    [9:0]                   tmds_ch0_data               ;
wire    [9:0]                   tmds_ch1_data               ;
wire    [9:0]                   tmds_ch2_data               ;
wire    [9:0]                   tmds_clk_data               ;

/*----------------------------------------------------------*/

always@(posedge sys_clk) begin
    if(sys_pll_reset_cnt != 16'hFFFF) begin
        sys_pll_reset_cnt <= sys_pll_reset_cnt + 1'b1;
    end

    sys_pll_reset <= sys_pll_reset_cnt == 16'hFFFF ? 1'b0 : 1'b1;
end



/*----------------------------------------------------------*/

reg     [23:0]                  sys_run_cnt                 ;

always@(posedge SYSCLK_50M) begin
    if(SYSRESET) begin
        sys_run_cnt <= 24'd0;
    end
    else begin
        sys_run_cnt <= sys_run_cnt + 1'b1;
    end
end

assign SYS_LED[0] = sys_run_cnt[23];
assign SYS_LED[1] = SYSCLK_LOCKED;
assign SYS_LED[2] = SD_SDIO_INIT_DONE;
assign SYS_LED[3] = hdmi_video_locked;

`ifndef SIM_MODE

SYS_PLL SYS_PLL(
    .refclk                     (sys_clk                    ),
    .reset                      (sys_pll_reset              ),
    .extlock                    (SYSCLK_LOCKED              ),
    .clk0_out                   (SYSCLK_50M                 ),
    .clk1_out                   (SYSCLK_150M                ),
    .clk2_out                   (SYSCLK_150M_S180           ),
    .clk3_out                   (SYSCLK_75M                 ),
    .clk4_out                   (SYSCLK_375M                ) 
);

`endif 

assign SYSRESET = !SYSCLK_LOCKED;


/*----------------------------------------------------------*/


/*----------------------------------------------------------*/

// wire                            VPI_SD_INIT_HOLD            ;
// reg     [2:0]                   VPI_SD_INIT_HOLD_r3         ;

// always@(posedge SYSCLK_50M) begin
//     VPI_SD_INIT_HOLD_r3 <= {VPI_SD_INIT_HOLD_r3[1:0],VPI_SD_INIT_HOLD};
// end

// VPI_INIT VPI_INIT
// (
//     .clk                        (SYSCLK_50M                 ),
//     .outprobe0                  (VPI_SD_INIT_HOLD           )
// );

assign SD_INIT_FLAG             = 1'b0;

/*----------------------------------------------------------*/

SDCARD_CTRL_TOP #(
    .CLK_FREQ                   (SD_SYS_CLK_FREQ            ),
    .CLK_SDIO_SPEED_MAX         (128 / 2                    ),
    .CLK_SDIO_SPEED_MIN         (8 / 2                      )
)SDCARD_CTRL_TOP(
    .clk                        (SYSCLK_50M                 ),
    .reset                      (SYSRESET                   ),

    .SD_INIT_FLAG               (SD_INIT_FLAG               ),
    .SD_SDIO_INIT_DONE          (SD_SDIO_INIT_DONE          ),

    .SD_SDIO_CLK                (SD_SDIO_CLK                ),
    .SD_SDIO_CMD                (SD_SDIO_CMD                ),
    .SD_SDIO_DATA               (SD_SDIO_DATA               ),

    .SD_USER_RD_REQ             (SD_USER_RD_REQ             ),
    .SD_USER_RD_ADDR            (SD_USER_RD_ADDR            ),
    .SD_USER_RD_ACK             (SD_USER_RD_ACK             ),

    .SD_USER_RD_START           (SD_USER_RD_START           ),
    .SD_USER_RD_DV              (SD_USER_RD_DV              ),
    .SD_USER_RD_DATA            (SD_USER_RD_DATA            ),
    .SD_USER_RD_END             (SD_USER_RD_END             ),
    .SD_USER_RD_CNT             (SD_USER_RD_CNT             ),
    .SD_USER_RD_ERR             (SD_USER_RD_ERR             ),

    .SD_USER_WR_REQ             (SD_USER_WR_REQ             ),
    .SD_USER_WR_ADDR            (SD_USER_WR_ADDR            ),
    .SD_USER_WR_ACK             (SD_USER_WR_ACK             ),

    .SD_USER_WR_DV              (SD_USER_WR_DV              ),
    .SD_USER_WR_DATA            (SD_USER_WR_DATA            ),
    .SD_USER_WR_END             (SD_USER_WR_END             ),
    .SD_USER_WR_ERR             (SD_USER_WR_ERR             )
);

assign SD_USER_RD_REQ           = !SD_INDEX_INIT_DONE ? SD_INDEX_R_REQ  :
                                  !SD_BMP_INIT_DONE   ? SD_BMP_R_REQ    : SD_AUDIO_R_REQ;
assign SD_USER_RD_ADDR          = !SD_INDEX_INIT_DONE ? SD_INDEX_R_ADDR :
                                  !SD_BMP_INIT_DONE   ? SD_BMP_R_ADDR   : SD_AUDIO_R_ADDR;

assign SD_INDEX_R_ACK           = !SD_INDEX_INIT_DONE ? SD_USER_RD_ACK : 1'b0;
assign SD_BMP_R_ACK             = (SD_INDEX_INIT_DONE && !SD_BMP_INIT_DONE) ? SD_USER_RD_ACK : 1'b0;
assign SD_AUDIO_R_ACK           = (SD_INDEX_INIT_DONE && SD_BMP_INIT_DONE) ? SD_USER_RD_ACK : 1'b0;

assign SD_INDEX_R_START         = !SD_INDEX_INIT_DONE ? SD_USER_RD_START : 1'b0;
assign SD_INDEX_R_DV            = !SD_INDEX_INIT_DONE ? SD_USER_RD_DV    : 1'b0;
assign SD_INDEX_R_DATA          = SD_USER_RD_DATA;
assign SD_INDEX_R_END           = !SD_INDEX_INIT_DONE ? SD_USER_RD_END : 1'b0;
assign SD_INDEX_R_CNT           = SD_USER_RD_CNT;
assign SD_INDEX_R_ERR           = !SD_INDEX_INIT_DONE ? SD_USER_RD_ERR : 1'b0;

assign SD_BMP_R_START           = (SD_INDEX_INIT_DONE && !SD_BMP_INIT_DONE) ? SD_USER_RD_START : 1'b0;
assign SD_BMP_R_DV              = (SD_INDEX_INIT_DONE && !SD_BMP_INIT_DONE) ? SD_USER_RD_DV    : 1'b0;
assign SD_BMP_R_DATA            = SD_USER_RD_DATA;
assign SD_BMP_R_END             = (SD_INDEX_INIT_DONE && !SD_BMP_INIT_DONE) ? SD_USER_RD_END : 1'b0;
assign SD_BMP_R_CNT             = SD_USER_RD_CNT;
assign SD_BMP_R_ERR             = (SD_INDEX_INIT_DONE && !SD_BMP_INIT_DONE) ? SD_USER_RD_ERR : 1'b0;

assign SD_AUDIO_R_START         = (SD_INDEX_INIT_DONE && SD_BMP_INIT_DONE) ? SD_USER_RD_START : 1'b0;
assign SD_AUDIO_R_DV            = (SD_INDEX_INIT_DONE && SD_BMP_INIT_DONE) ? SD_USER_RD_DV    : 1'b0;
assign SD_AUDIO_R_DATA          = SD_USER_RD_DATA;
assign SD_AUDIO_R_END           = (SD_INDEX_INIT_DONE && SD_BMP_INIT_DONE) ? SD_USER_RD_END : 1'b0;
assign SD_AUDIO_R_CNT           = SD_USER_RD_CNT;
assign SD_AUDIO_R_ERR           = (SD_INDEX_INIT_DONE && SD_BMP_INIT_DONE) ? SD_USER_RD_ERR : 1'b0;  

SDCARD_INDEX_READ SDCARD_INDEX_READ(
    .clk                        (SYSCLK_50M                 ),
    .reset                      (SYSRESET                   ),

    .sd_init_done               (SD_SDIO_INIT_DONE          ),

    .sd_index_init_flag         (SD_INDEX_INIT_FLAG         ),
    .sd_index_init_done         (SD_INDEX_INIT_DONE         ),

    .sd_index_r_req             (SD_INDEX_R_REQ             ),
    .sd_index_r_addr            (SD_INDEX_R_ADDR            ),
    .sd_index_r_ack             (SD_INDEX_R_ACK             ),
    .sd_index_r_start           (SD_INDEX_R_START           ),
    .sd_index_r_dv              (SD_INDEX_R_DV              ),
    .sd_index_r_data            (SD_INDEX_R_DATA            ),
    .sd_index_r_end             (SD_INDEX_R_END             ),
    .sd_index_r_cnt             (SD_INDEX_R_CNT             ),
    .sd_index_r_err             (SD_INDEX_R_ERR             ),

    .sd_bmp_Structures_flag     (SD_BMP_STRUSTURES_FLAG     ),
    .sd_bmp_Structures_cnt      (SD_BMP_STRUSTURES_CNT      ),
    .sd_bmp_Structures_data     (SD_BMP_STRUSTURES_DATA     ),//24+32+13+13

    .sd_audio_Structures_flag   (SD_AUDIO_STRUSTURES_FLAG   ),
    .sd_audio_Structures_cnt    (SD_AUDIO_STRUSTURES_CNT    ),
    .sd_audio_Structures_data   (SD_AUDIO_STRUSTURES_DATA   ) //24+32+32+4+6
);

assign SD_BMP_INIT_FLAG         = KEY_INDEPENDENT_FLAG[1]   ;


SDCARD_BMP_READ SDCARD_BMP_READ(
    .clk                        (SYSCLK_50M                 ),
    .reset                      (SYSRESET                   ),

    .sd_index_init_done         (SD_INDEX_INIT_DONE & SDRAM_INIT_DONE   ),

    .sd_bmp_init_flag           (SD_BMP_INIT_FLAG           ),
    .sd_bmp_init_done           (SD_BMP_INIT_DONE           ),

    .sd_bmp_Structures_flag     (SD_BMP_STRUSTURES_FLAG     ),
    .sd_bmp_Structures_cnt      (SD_BMP_STRUSTURES_CNT      ),
    .sd_bmp_Structures_data     (SD_BMP_STRUSTURES_DATA     ),//24+32+13+13

    .sd_bmp_r_req               (SD_BMP_R_REQ               ),
    .sd_bmp_r_addr              (SD_BMP_R_ADDR              ),
    .sd_bmp_r_ack               (SD_BMP_R_ACK               ),
    .sd_bmp_r_start             (SD_BMP_R_START             ),
    .sd_bmp_r_dv                (SD_BMP_R_DV                ),
    .sd_bmp_r_data              (SD_BMP_R_DATA              ),
    .sd_bmp_r_end               (SD_BMP_R_END               ),
    .sd_bmp_r_cnt               (SD_BMP_R_CNT               ),
    .sd_bmp_r_err               (SD_BMP_R_ERR               ),

    .sd_bmp_out_start           (SD_BMP_OUT_START           ),
    .sd_bmp_out_index           (SD_BMP_OUT_INDEX           ),
    .sd_bmp_out_width           (SD_BMP_OUT_WIDTH           ),
    .sd_bmp_out_height          (SD_BMP_OUT_HEIGHT          ),
    .sd_bmp_out_dv              (SD_BMP_OUT_DV              ),
    .sd_bmp_out_data            (SD_BMP_OUT_DATA            ),
    .sd_bmp_out_xcnt            (SD_BMP_OUT_XCNT            ),
    .sd_bmp_out_ycnt            (SD_BMP_OUT_YCNT            )
);

assign SD_AUDIO_PREVIOUS       = 1'b0                      ;
assign SD_AUDIO_NEXT            = key_audio_next            ;
assign SD_AUDIO_LOOP            = 1'b0                      ;

SDCARD_AUDIO_READ #(
    .CLK_FREQ                   (SD_SYS_CLK_FREQ            )
)SDCARD_AUDIO_READ(
    .clk                        (SYSCLK_50M                 ),
    .reset                      (SYSRESET                   ),

    .sd_bmp_init_done           (SD_BMP_INIT_DONE           ),

    .sd_audio_previous          (SD_AUDIO_PREVIOUS          ),
    .sd_audio_next              (SD_AUDIO_NEXT              ),
    .sd_audio_loop              (SD_AUDIO_LOOP              ),

    .sd_audio_Structures_flag   (SD_AUDIO_STRUSTURES_FLAG   ),
    .sd_audio_Structures_cnt    (SD_AUDIO_STRUSTURES_CNT    ),
    .sd_audio_Structures_data   (SD_AUDIO_STRUSTURES_DATA   ),

    .sd_audio_r_req             (SD_AUDIO_R_REQ             ),
    .sd_audio_r_addr            (SD_AUDIO_R_ADDR            ),
    .sd_audio_r_ack             (SD_AUDIO_R_ACK             ),
    .sd_audio_r_start           (SD_AUDIO_R_START           ),
    .sd_audio_r_dv              (SD_AUDIO_R_DV              ),
    .sd_audio_r_data            (SD_AUDIO_R_DATA            ),
    .sd_audio_r_end             (SD_AUDIO_R_END             ),
    .sd_audio_r_cnt             (SD_AUDIO_R_CNT             ),
    .sd_audio_r_err             (SD_AUDIO_R_ERR             ),

    .sd_audio_fifo_clk          (SYSCLK_75M                 ),
    .sd_audio_fifo_req          (ARC_AUDIO_REQ              ),
    .sd_audio_fifo_ack          (ARC_AUDIO_ACK              ),
    .sd_audio_fifo_data         (ARC_AUDIO_DATA             )
);

`ifndef SIM_SD_ONLY
/*----------------------------------------------------------*/

EG4_SDRAM_WR_CTRL EG4_SDRAM_WR_CTRL(
    .clk                        (SYSCLK_50M                 ),
    .reset                      (SYSRESET                   ),

    .sd_bmp_wr_start            (SD_BMP_OUT_START           ),
    .sd_bmp_wr_index            (SD_BMP_OUT_INDEX           ),
    .sd_bmp_wr_width            (SD_BMP_OUT_WIDTH           ),
    .sd_bmp_wr_height           (SD_BMP_OUT_HEIGHT          ),
    .sd_bmp_wr_dv               (SD_BMP_OUT_DV              ),
    .sd_bmp_wr_data             (SD_BMP_OUT_DATA            ),
    .sd_bmp_wr_xcnt             (SD_BMP_OUT_XCNT            ),
    .sd_bmp_wr_ycnt             (SD_BMP_OUT_YCNT            ),

    .sdram_clk                  (SYSCLK_150M                ),

    .Sdr_init_done              (SDRAM_INIT_DONE            ),
    .Sdr_init_ref_vld           (SDRAM_INIT_REF_VAL         ),
    .Sdr_ref_hold               (SDRAM_REF_HOLD             ),

    .arbit_req                  (SDRAM_ARBIT_REQ        [0] ),
    .arbit_end                  (SDRAM_ARBIT_REQ_END    [0] ),
    .arbit_allow                (SDRAM_ARBIT_ALLOW      [0] ),

    .App_wr_en                  (SDRAM_APP_WR_EN            ),
    .App_wr_addr                (SDRAM_APP_WR_ADDR          ), 	
    .App_wr_dm                  (SDRAM_APP_WR_DM            ),
    .App_wr_din                 (SDRAM_APP_WR_DIN           )
);



ARBIT_XPORT#(
    .PORT_NUM                   (3                          )
)EG4_SDRAM_ARBIT(
    .clk                        (SYSCLK_150M                ),
    .reset                      (SYSRESET                   ),

    .init_done                  (SDRAM_INIT_DONE            ),

    .i_request                  (SDRAM_ARBIT_REQ            ),
    .i_request_end              (SDRAM_ARBIT_REQ_END        ),
    .o_request_allow            (SDRAM_ARBIT_ALLOW          )  
);

`ifdef SIM_MODE

// assign SDRAM_INDEX_CHANGE_AUTO  = 1'b1                      ;
assign SDRAM_INDEX_CHANGE_AUTO  = 1'b0                      ;
assign SDRAM_INDEX_CHANGE_TIME  = 8'd1                      ;
assign SDRAM_INDEX_CHANGE_FLAG  = 1'b0                      ;

assign SDRAM_SET_INDEX_MAX      = 8'd6                      ;

`else

assign SDRAM_INDEX_CHANGE_AUTO  = key_sw_level[1]           ;
assign SDRAM_INDEX_CHANGE_TIME  = 8'd120                    ;
assign SDRAM_INDEX_CHANGE_FLAG  = key_pic_pulse             ;

assign SDRAM_SET_INDEX_MAX      = 8'd8                      ;

`endif 


EG4_SDRAM_INDEX_CHANGE #(
    .CLK_FREQ                   (SDRAM_CLK_FREQ             )
)EG4_SDRAM_INDEX_CHANGE(
    .clk                        (SYSCLK_150M                ),
    .reset                      (SYSRESET                   ),

    .sdram_index_change_auto    (SDRAM_INDEX_CHANGE_AUTO    ),// auto : 1 ; manual : 0;
    .sdram_index_change_time    (SDRAM_INDEX_CHANGE_TIME    ),// auto change frame rate 
    .sdram_index_change_flag    (SDRAM_INDEX_CHANGE_FLAG    ),// manual change

    .sdram_set_index_max        (SDRAM_SET_INDEX_MAX        ),

    .sdram_picturex_change      (SDRAM_PICTUREX_CHANGE      ),
    .sdram_picture1_index       (SDRAM_PICTURE1_INDEX       ),
    .sdram_picture2_index       (SDRAM_PICTURE2_INDEX       ),
    .sdram_change_done_tog      (VPU_CUT_DONE_TOG           ),
    .hdmi_vsync                 (O_HDMI_VSYNC               ),
    .cut_disable                (VPU_CUT_DISABLE            )
);

assign SDRAM_ARBIT_REQ[1]       = SCALE_REQ                 ;
assign SDRAM_ARBIT_REQ[2]       = 1'b0                      ;
assign SDRAM_ARBIT_REQ_END[1]   = SCALE_END                 ;
assign SDRAM_ARBIT_REQ_END[2]   = 1'b0                      ;

EG4_SDRAM_SCALE_RD EG4_SDRAM_SCALE_RD(
    .clk                        (SYSCLK_150M                ),
    .clk_pix                    (SYSCLK_75M                 ),
    .reset                      (SYSRESET                   ),
    .flush                      (SCALE_FLUSH                ),

    .enable                     (SCALE_PORT                 ),
    .vsync                      (O_HDMI_VSYNC               ),
    .picture                    (SDRAM_PICTURE1_INDEX       ),
    .picture2                   (SDRAM_PICTURE2_INDEX       ),
    .line_pic                   (SCALE_LINE_PIC             ),
    .src_w                      (SD_BMP_OUT_WIDTH           ),
    .init_done                  (SDRAM_INIT_DONE            ),
    .ref_vld                    (SDRAM_INIT_REF_VAL         ),
    .ref_hold                   (SDRAM_REF_HOLD             ),

    .line_req                   (SCALE_LINE_REQ             ),
    .line_y                     (SCALE_LINE_Y               ),
    .line_bank                  (SCALE_LINE_BANK            ),
    .line_ack                   (SCALE_LINE_ACK             ),

    .arbit_req                  (SCALE_REQ                  ),
    .arbit_end                  (SCALE_END                  ),
    .arbit_allow                (SDRAM_ARBIT_ALLOW[1]       ),

    .App_rd_en                  (SDRAM_APP_RD_EN            ),
    .App_rd_addr                (SDRAM_APP_RD_ADDR          ),
    .Sdr_rd_en                  (SDRAM_APP_RD_DV            ),
    .Sdr_rd_dout                (SDRAM_APP_RD_DATA          ),

    .pix_re                     (SCALE_PIX_RE               ),
    .pix_data                   (SCALE_PIX_DATA             ),
    .pix_empty                  (SCALE_PIX_EMPTY            ),
    .pix_valid                  (SCALE_PIX_VALID            )
);

EG4_SDRAM_TOP EG4_SDRAM_TOP(
    .sdram_clk                  (SYSCLK_150M                ),
    .sdram_clk_s180             (SYSCLK_150M_S180           ),
    .sdram_reset                (SYSRESET                   ),

    .Sdr_init_done              (SDRAM_INIT_DONE            ),
    .Sdr_init_ref_vld           (SDRAM_INIT_REF_VAL         ),
    .Sdr_busy                   (SDRAM_BUSY                 ),
    .Sdr_ref_hold               (SDRAM_REF_HOLD             ),

    .App_wr_en                  (SDRAM_APP_WR_EN            ),
    .App_wr_addr                (SDRAM_APP_WR_ADDR          ), 	
    .App_wr_dm                  (SDRAM_APP_WR_DM            ),
    .App_wr_din                 (SDRAM_APP_WR_DIN           ),

    .App_rd_en                  (SDRAM_APP_RD_EN            ),
    .App_rd_addr                (SDRAM_APP_RD_ADDR          ),
    .Sdr_rd_en                  (SDRAM_APP_RD_DV            ),
    .Sdr_rd_dout                (SDRAM_APP_RD_DATA          )
);

/*----------------------------------------------------------*/

HDMI_DRIVER_TOP #(
    .HDMI_MODE_SEL              (HDMI_VIDEO_MODE            )
)HDMI_DRIVER_TOP(
    .HDMI_CLK                   (SYSCLK_75M                 ),  
    .RESET                      (SYSRESET                   ),

    .HDMI_INIT_DONE             (hdmi_video_locked          ),
    .HDMI_BLACK_LOCKED          (1'b0                       ),

    // .HDMI_VALID_WIDTH           (13'd640                    ),
    // .HDMI_VALID_HEIGHT          (13'd480                    ),
    .HDMI_VALID_WIDTH           (SD_BMP_OUT_WIDTH           ),
    .HDMI_VALID_HEIGHT          (SD_BMP_OUT_HEIGHT          ),

    .SDRAM_CLK                  (SYSCLK_150M                ),
    .SDRAM_P1_DV                (1'b0                       ),
    .SDRAM_P1_DATA              (24'd0                      ),
    .SDRAM_P2_DV                (1'b0                       ),
    .SDRAM_P2_DATA              (24'd0                      ),
    
    .HDMI_BUFFER1_REQ           (                           ),
    .HDMI_FRAMER1_DONE          (1'b1                       ),
    .HDMI_BUFFER2_REQ           (                           ),
    .HDMI_FRAMER2_DONE          (1'b1                       ),

    .O_HDMI_VSYNC               (O_HDMI_VSYNC               ), 
    .O_HDMI_HSYNC               (O_HDMI_HSYNC               ), 
    .O_HDMI_DE                  (O_HDMI_DE                  ), 
    .O_HDMI_XCNT                (O_HDMI_XCNT                ),
    .O_HDMI_YCNT                (O_HDMI_YCNT                ),
    .O_HDMI_RGB1                (O_HDMI_RGB1                ),
    .O_HDMI_RGB2                (O_HDMI_RGB2                )
);


wire                            VPU_OUT_VSYNC               ;//(*mark_debug = "true"*)
wire                            VPU_OUT_HSYNC               ;//(*mark_debug = "true"*)
wire                            VPU_OUT_DE                  ;//(*mark_debug = "true"*)
wire    [12:0]                  VPU_OUT_XCNT                ;//(*mark_debug = "true"*)
wire    [12:0]                  VPU_OUT_YCNT                ;//(*mark_debug = "true"*)
wire    [23:0]                  VPU_OUT_RGB                 ;//(*mark_debug = "true"*)


VPU_SUBSYS_TOP #(
    .CLK_FREQ                   (75_000_000                 )
)VPU_SUBSYS_TOP(
    .clk                        (SYSCLK_75M                 ),
    .reset                      (SYSRESET                   ),

    .key_sw0                    (key_sw_level[0]            ),
    .key_sw2                    (key_sw_level[2]            ),
    .key_left                   (key_nav_left               ),
    .key_ok                     (key_nav_ok                 ),
    .key_right                  (key_nav_right              ),

    .scale_run                  (SCALE_RUN                  ),
    .scale_flush                (SCALE_FLUSH                ),
    .scale_line_req             (SCALE_LINE_REQ             ),
    .scale_line_y               (SCALE_LINE_Y               ),
    .scale_line_bank            (SCALE_LINE_BANK            ),
    .scale_line_pic             (SCALE_LINE_PIC             ),
    .scale_line_ack             (SCALE_LINE_ACK             ),
    .scale_pix_re               (SCALE_PIX_RE               ),
    .scale_pix_data             (SCALE_PIX_DATA             ),
    .scale_pix_empty            (SCALE_PIX_EMPTY            ),
    .scale_pix_valid            (SCALE_PIX_VALID            ),

    // .vpu_valid_width            (13'd640                    ),
    // .vpu_valid_height           (13'd480                    ),
    .vpu_valid_width            (SD_BMP_OUT_WIDTH           ),
    .vpu_valid_height           (SD_BMP_OUT_HEIGHT          ),

    .vpu_uart_rx                (UART_RXD                   ),
    .vpu_uart_tx                (UART_TXD                   ),

    .vpu_audio_valid            (hdmi_audio_valid           ),
    .vpu_audio_data             (hdmi_audio_left_data[23:8] ),

    .vpu_in_pchange             (SDRAM_PICTUREX_CHANGE      ),//async
    .vpu_in_vsync               (O_HDMI_VSYNC               ),
    .vpu_in_hsync               (O_HDMI_HSYNC               ),
    .vpu_in_de                  (O_HDMI_DE                  ),
    .vpu_in_xcnt                (O_HDMI_XCNT                ),
    .vpu_in_ycnt                (O_HDMI_YCNT                ),
    .vpu_in_rgb1                (O_HDMI_RGB1                ),
    .vpu_in_rgb2                (O_HDMI_RGB2                ),

    .vpu_out_vsync              (VPU_OUT_VSYNC              ),
    .vpu_out_hsync              (VPU_OUT_HSYNC              ),
    .vpu_out_de                 (VPU_OUT_DE                 ),
    .vpu_out_xcnt               (VPU_OUT_XCNT               ),
    .vpu_out_ycnt               (VPU_OUT_YCNT               ),
    .vpu_out_rgb                (VPU_OUT_RGB                ),
    .vpu_cut_active             (VPU_CUT_ACTIVE             ),
    .vpu_cut_done_tog           (VPU_CUT_DONE_TOG           ),
    .vpu_cut_disable            (VPU_CUT_DISABLE            ),
    .scale_want                 (SCALE_WANT                 )
);

HDMI_VIDEO_TO_AXI HDMI_VIDEO_TO_AXI(
    .clk                        (SYSCLK_75M                 ),
    .reset                      (SYSRESET                   ),

    .in_hdmi_locked             (SD_BMP_INIT_DONE           ),

    .in_hdmi_vsync              (VPU_OUT_VSYNC              ),
    .in_hdmi_hsync              (VPU_OUT_HSYNC              ),
    .in_hdmi_de                 (VPU_OUT_DE                 ),
    .in_hdmi_data               (VPU_OUT_RGB                ),
    // .in_hdmi_vsync              (O_HDMI_VSYNC               ),
    // .in_hdmi_hsync              (O_HDMI_HSYNC               ),
    // .in_hdmi_de                 (O_HDMI_DE                  ),
    // .in_hdmi_data               (O_HDMI_RGB1                ),

    .hdmi_axis_s_ready          (hdmi_axis_s_ready          ),

    .hdmi_axis_s_user           (hdmi_axis_s_user           ),
    .hdmi_axis_s_valid          (hdmi_axis_s_valid          ),
    .hdmi_axis_s_last           (hdmi_axis_s_last           ),
    .hdmi_axis_s_data           (hdmi_axis_s_data           )            
);

AUDIO_ARC_TOP #(
    .CLK_FREQ                   (75_000_000                 )
)AUDIO_ARC_TOP(
    .clk                        (SYSCLK_75M                 ),
    .reset                      (SYSRESET                   ),

    .audio_enable               (1'b1                       ),

    .sd_audio_req               (ARC_AUDIO_REQ              ),
    .sd_audio_ack               (ARC_AUDIO_ACK              ),
    .sd_audio_data              (ARC_AUDIO_DATA             ),

    .audio_data_valid           (hdmi_audio_valid           ),
    .audio_data_left            (hdmi_audio_left_data       ),
    .audio_data_right           (hdmi_audio_right_data      ),

    .audio_arc_valid            (hdmi_acr_valid             ),
    .audio_arc_cts              (hdmi_acr_cts               ),
    .audio_arc_n                (hdmi_acr_n                 )
);

// ===================== 带音频的 HDMI 1.4b 发射 =====================

hdmi_1_4b_transmitter_core_wrapper #(
    .DEVICE                     ( "EG"                      ),
    .HTOTAL                     ( HDMI_HTOTAL               ),
    .HSA                        ( HDMI_HSA                  ),
    .HFP                        ( HDMI_HFP                  ),
    .HBP                        ( HDMI_HBP                  ),
    .HACTIVE                    ( HDMI_HACTIVE              ),
    .VTOTAL                     ( HDMI_VTOTAL               ),
    .VSA                        ( HDMI_VSA                  ),
    .VFP                        ( HDMI_VFP                  ),
    .VBP                        ( HDMI_VBP                  ),
    .VACTIVE                    ( HDMI_VACTIVE              ),
    .VIDEO_VIC                  ( HDMI_VIDEO_VIC            ),
    .VIDEO_TPG                  ( "Disable"                 ), //Enable  //Disable
    .VIDEO_FORMAT               ( "RGB"                     ),
    .AUDIO_SAMPLE_RATE          ( "48K"                     ),
    .IIC_SCL_DIV                ( 250                       )
)hdmi_1_4b_transmitter_core_wrapper(
    .I_pixel_clk                (SYSCLK_75M                 ),
    .I_rst                      (SYSRESET                   ),
    .I_edid_read_trig           (1'b0                       ),
    .O_edid_read_valid          (                           ),
    .O_edid_read_data           (                           ),

    .I_axis_s_user              (hdmi_axis_s_user           ),
    .I_axis_s_valid             (hdmi_axis_s_valid          ),
    .I_axis_s_last              (hdmi_axis_s_last           ),
    .I_axis_s_data              (hdmi_axis_s_data           ),
    .O_axis_s_ready             (hdmi_axis_s_ready          ),

    .I_audio_valid              (hdmi_audio_valid           ),
    .I_audio_left_data          (hdmi_audio_left_data       ),
    .I_audio_right_data         (hdmi_audio_right_data      ),

    .I_acr_valid                (hdmi_acr_valid             ),
    .I_acr_cts                  (hdmi_acr_cts               ),
    .I_acr_n                    (hdmi_acr_n                 ),

    .O_video_locked             (hdmi_video_locked          ),
    .O_ddc_scl                  (HDMIB_DDC_SCL              ),
    .IO_ddc_sda                 (HDMIB_DDC_SDA              ),

    .O_ch0_tmds_data            (tmds_ch0_data              ),
    .O_ch1_tmds_data            (tmds_ch1_data              ),
    .O_ch2_tmds_data            (tmds_ch2_data              ),
    .O_clk_tmds_data            (tmds_clk_data              )
);


hdmi_phy_wrapper #(
    .DEVICE                     ( "EG"                      )
)hdmi_phy_wrapper(
    .I_pixel_clk                (SYSCLK_75M                 ),
    .I_serial_clk               (SYSCLK_375M                ),
    .I_rst                      (SYSRESET                   ),
    .I_tmds_channel_0           (tmds_ch0_data              ),
    .I_tmds_channel_1           (tmds_ch1_data              ),
    .I_tmds_channel_2           (tmds_ch2_data              ),
    .I_tmds_channel_clk         (tmds_clk_data              ),
    .O_tmds_ch0_p               (HDMIB_D0_P                 ),
    .O_tmds_ch1_p               (HDMIB_D1_P                 ),
    .O_tmds_ch2_p               (HDMIB_D2_P                 ),
    .O_tmds_clk_p               (HDMIB_CLK_P                )
);

`else

assign SDRAM_INIT_DONE = 1'b1;

`endif 






















/*----------------------------------------------------------*/


/*----------------------------------------------------------*/



endmodule
