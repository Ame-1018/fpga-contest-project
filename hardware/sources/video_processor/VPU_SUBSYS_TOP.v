`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Create Date: 2026/10/08 09:21:17
// Design Name: 
// Module Name: VPU_SUBSYS_TOP
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

module VPU_SUBSYS_TOP #(
    parameter                   CLK_FREQ                    = 75_000_000
)(
    input   wire                clk                         ,
    input   wire                reset                       ,

    input   wire                key_sw0                     ,
    input   wire                key_sw2                     ,
    input   wire                key_left                    ,
    input   wire                key_ok                      ,
    input   wire                key_right                   ,

    output  wire                scale_run                   ,
    output  wire                scale_flush                 ,
    output  wire                scale_line_req              ,
    output  wire    [12:0]      scale_line_y                ,
    output  wire    [1:0]       scale_line_bank             ,
    output  wire                scale_line_pic              ,
    input   wire                scale_line_ack              ,
    output  wire                scale_pix_re                ,
    input   wire    [23:0]      scale_pix_data              ,
    input   wire                scale_pix_empty             ,
    input   wire                scale_pix_valid             ,

    input   wire                vpu_uart_rx                 ,
    output  wire                vpu_uart_tx                 ,

    input   wire    [12:0]      vpu_valid_width             ,
    input   wire    [12:0]      vpu_valid_height            ,

    input   wire                vpu_audio_valid             ,
    input   wire    [15:0]      vpu_audio_data              ,

    input   wire                vpu_in_pchange              ,
    input   wire                vpu_in_vsync                ,
    input   wire                vpu_in_hsync                ,
    input   wire                vpu_in_de                   ,
    input   wire    [12:0]      vpu_in_xcnt                 ,
    input   wire    [12:0]      vpu_in_ycnt                 ,
    input   wire    [23:0]      vpu_in_rgb1                 ,
    input   wire    [23:0]      vpu_in_rgb2                 ,

    output  wire                vpu_out_vsync               ,
    output  wire                vpu_out_hsync               ,
    output  wire                vpu_out_de                  ,
    output  wire    [12:0]      vpu_out_xcnt                ,
    output  wire    [12:0]      vpu_out_ycnt                ,
    output  wire    [23:0]      vpu_out_rgb                 ,

    output  wire                vpu_cut_active              ,
    output  wire                vpu_cut_done_tog            ,
    output  wire                vpu_cut_disable             ,
    output  wire                scale_want
);

wire                            cut_to_disable              ;
wire    [2:0]                   cut_to_mode_set             ;
wire    [1:0]                   cut_to_speed_set            ;

wire                            dis_eff_disable             ;
wire    [7:0]                   lumi_set_data               ;
wire    [7:0]                   contrast_set_data           ;
wire    [7:0]                   temp_set_data               ;
wire    [7:0]                   tint_set_data               ;

wire                            osd_disable                 ;
wire    [12:0]                  osd_logo_sx                 ;
wire    [12:0]                  osd_logo_sy                 ;

wire    [12:0]                  osd_txt_sx                  ;
wire    [12:0]                  osd_txt_sy                  ;
wire    [12:0]                  osd_txt_x_area              ;
wire    [1:0]                   osd_txt_speed               ;
wire    [1:0]                   osd_color_mode              ;
wire    [23:0]                  osd_color_set               ;
wire                            osd_txt_disable             ;

wire                            osd_txtram_dv               ;
wire    [31:0]                  osd_txtram_data             ;
wire    [10:0]                  osd_txtram_addr             ;

wire                            vpu_audio_disable           ;
wire    [1:0]                   vpu_audio_mode              ;
wire    [1:0]                   vpu_audio_color_mode        ;
wire    [23:0]                  vpu_audio_color_data        ;
wire    [12:0]                  vpu_audio_sx                ;
wire    [12:0]                  vpu_audio_sy                ;

wire                            vpu_scaler_disable          ;
wire    [12:0]                  vpu_scaler_target_width     ;
wire    [12:0]                  vpu_scaler_target_height    ;

wire                            style_disable               ;
wire    [2:0]                   style_mode                  ;
wire    [7:0]                   style_bin_th                ;
wire    [7:0]                   style_gamma                 ;

/*----------------------------------------------------------*/

wire                            cut_to_out_done             ;
wire                            cut_to_active               ;
reg                             cut_done_tog                ;

wire                            audio_out_vsync             ;
wire                            audio_out_hsync             ;
wire                            audio_out_de                ;
wire    [12:0]                  audio_out_xcnt              ;
wire    [12:0]                  audio_out_ycnt              ;
wire    [23:0]                  audio_out_rgb               ;

wire                            dis_eff_out_vsync           ;
wire                            dis_eff_out_hsync           ;
wire                            dis_eff_out_de              ;
wire    [12:0]                  dis_eff_out_xcnt            ;
wire    [12:0]                  dis_eff_out_ycnt            ;
wire    [23:0]                  dis_eff_out_rgb             ;

wire                            style_out_vsync             ;
wire                            style_out_hsync             ;
wire                            style_out_de                ;
wire    [12:0]                  style_out_xcnt              ;
wire    [12:0]                  style_out_ycnt              ;
wire    [23:0]                  style_out_rgb               ;

wire                            fill_vsync                  ;
wire                            fill_hsync                  ;
wire                            fill_de                     ;
wire    [12:0]                  fill_xcnt                   ;
wire    [12:0]                  fill_ycnt                   ;
wire    [23:0]                  fill_rgb                    ;
wire    [12:0]                  fill_dst_w                  ;
wire    [12:0]                  fill_dst_h                  ;

wire                            osd_out_vsync               ;
wire                            osd_out_hsync               ;
wire                            osd_out_de                  ;
wire    [12:0]                  osd_out_xcnt                ;
wire    [12:0]                  osd_out_ycnt                ;
wire    [23:0]                  osd_out_rgb                 ;

UART_SUBSYS_TOP#(
    .CLK_FREQ                   (CLK_FREQ                   )
)UART_SUBSYS_TOP(
    .clk                        (clk                        ),
    .reset                      (reset                      ),

    .vpu_uart_rx                (vpu_uart_rx                ),
    .vpu_uart_tx                (vpu_uart_tx                ),

    .uart_cut_to_disable        (cut_to_disable             ),
    .uart_cut_to_mode           (cut_to_mode_set            ),
    .uart_cut_to_speed          (cut_to_speed_set           ),

    .uart_dis_eff_disable       (dis_eff_disable            ),
    .uart_lumi_set_data         (lumi_set_data              ),
    .uart_contrast_set_data     (contrast_set_data          ),
    .uart_temp_set_data         (temp_set_data              ),
    .uart_tint_set_data         (tint_set_data              ),

    .uart_osd_disable           (osd_disable                ),
    .uart_osd_logo_sx           (osd_logo_sx                ),
    .uart_osd_logo_sy           (osd_logo_sy                ),

    .uart_osd_txt_sx            (osd_txt_sx                 ),
    .uart_osd_txt_sy            (osd_txt_sy                 ),
    .uart_osd_txt_x_area        (osd_txt_x_area             ),
    .uart_osd_txt_speed         (osd_txt_speed              ),
    .uart_osd_color_mode        (osd_color_mode             ),
    .uart_osd_color_set         (osd_color_set              ),

    .uart_osd_txtram_disable    (osd_txt_disable            ),
    .uart_osd_txtram_dv         (osd_txtram_dv              ),
    .uart_osd_txtram_data       (osd_txtram_data            ),
    .uart_osd_txtram_addr       (osd_txtram_addr            ),

    .uart_vpu_audio_disable     (vpu_audio_disable          ),
    .uart_vpu_audio_mode        (vpu_audio_mode             ),
    .uart_vpu_audio_color_mode  (vpu_audio_color_mode       ),
    .uart_vpu_audio_color_data  (vpu_audio_color_data       ),
    .uart_vpu_audio_sx          (vpu_audio_sx               ),
    .uart_vpu_audio_sy          (vpu_audio_sy               ),

    .uart_scaler_disable        (vpu_scaler_disable         ),
    .uart_scaler_target_width   (vpu_scaler_target_width    ),
    .uart_scaler_target_height  (vpu_scaler_target_height   ),

    .uart_style_disable         (style_disable              ),
    .uart_style_mode            (style_mode                 ),
    .uart_style_bin_th          (style_bin_th               ),
    .uart_style_gamma           (style_gamma                ),

    .key_we                     (key_we                     ),
    .key_id                     (key_id                     ),
    .key_data                   (key_data                   )
);

wire                            key_we                      ;
wire    [5:0]                   key_id                      ;
wire    [12:0]                  key_data                    ;
wire                            menu_on                     ;
wire                            menu_uart                   ;
wire    [2:0]                   menu_page                   ;
wire    [3:0]                   menu_item                   ;
wire                            menu_edit                   ;

key_menu #(
    .CLK_FREQ                   (CLK_FREQ                   )
)key_menu(
    .clk                        (clk                        ),
    .reset                      (reset                      ),
    .sw0_in                     (key_sw0                    ),
    .sw2_in                     (key_sw2                    ),
    .nav_left                   (key_left                   ),
    .nav_ok                     (key_ok                     ),
    .nav_right                  (key_right                  ),
    .cut_disable                (cut_to_disable             ),
    .cut_mode                   (cut_to_mode_set            ),
    .cut_speed                  (cut_to_speed_set           ),
    .color_disable              (dis_eff_disable            ),
    .lumi                       (lumi_set_data              ),
    .contrast                   (contrast_set_data          ),
    .temp                       (temp_set_data              ),
    .tint                       (tint_set_data              ),
    .style_disable              (style_disable              ),
    .style_mode                 (style_mode                 ),
    .style_th                   (style_bin_th               ),
    .style_gamma                (style_gamma                ),
    .osd_disable                (osd_disable                ),
    .logo_x                     (osd_logo_sx                ),
    .logo_y                     (osd_logo_sy                ),
    .txt_disable                (osd_txt_disable            ),
    .txt_x                      (osd_txt_sx                 ),
    .txt_y                      (osd_txt_sy                 ),
    .txt_w                      (osd_txt_x_area             ),
    .txt_speed                  (osd_txt_speed              ),
    .txt_cmode                  (osd_color_mode             ),
    .txt_color                  (osd_color_set              ),
    .aud_disable                (vpu_audio_disable          ),
    .aud_mode                   (vpu_audio_mode             ),
    .aud_cmode                  (vpu_audio_color_mode       ),
    .aud_color                  (vpu_audio_color_data       ),
    .aud_x                      (vpu_audio_sx               ),
    .aud_y                      (vpu_audio_sy               ),
    .scale_disable              (vpu_scaler_disable         ),
    .scale_w                    (vpu_scaler_target_width    ),
    .scale_h                    (vpu_scaler_target_height   ),
    .menu_on                    (menu_on                    ),
    .menu_uart                  (menu_uart                  ),
    .menu_page                  (menu_page                  ),
    .menu_item                  (menu_item                  ),
    .menu_edit                  (menu_edit                  ),
    .key_we                     (key_we                     ),
    .key_id                     (key_id                     ),
    .key_data                   (key_data                   )
);

/*----------------------------------------------------------*/

VPU_display_effect VPU_display_effect(
    .clk                        (clk                        ),
    .reset                      (reset                      ),

    .dis_eff_valid_width        (scale_run ? fill_dst_w : vpu_valid_width),
    .dis_eff_valid_height       (scale_run ? fill_dst_h : vpu_valid_height),

    .dis_eff_disable            (dis_eff_disable            ),

    .lumi_set_data              (lumi_set_data              ),
    .contrast_set_data          (contrast_set_data          ),
    .temp_set_data              (temp_set_data              ),
    .tint_set_data              (tint_set_data              ),

    .dis_eff_in_vsync           (fill_vsync                 ),
    .dis_eff_in_hsync           (fill_hsync                 ),
    .dis_eff_in_de              (fill_de                    ),
    .dis_eff_in_xcnt            (fill_xcnt                  ),
    .dis_eff_in_ycnt            (fill_ycnt                  ),
    .dis_eff_in_rgb             (fill_rgb                   ),

    .dis_eff_out_vsync          (dis_eff_out_vsync          ),
    .dis_eff_out_hsync          (dis_eff_out_hsync          ),
    .dis_eff_out_de             (dis_eff_out_de             ),
    .dis_eff_out_xcnt           (dis_eff_out_xcnt           ),
    .dis_eff_out_ycnt           (dis_eff_out_ycnt           ),
    .dis_eff_out_rgb            (dis_eff_out_rgb            )
);

VPU_style VPU_style(
    .clk                        (clk                        ),
    .reset                      (reset                      ),

    .style_disable              (style_disable              ),
    .style_mode                 (style_mode                 ),
    .style_bin_th               (style_bin_th               ),
    .style_gamma                (style_gamma                ),

    .style_in_vsync             (dis_eff_out_vsync          ),
    .style_in_hsync             (dis_eff_out_hsync          ),
    .style_in_de                (dis_eff_out_de             ),
    .style_in_xcnt              (dis_eff_out_xcnt           ),
    .style_in_ycnt              (dis_eff_out_ycnt           ),
    .style_in_rgb               (dis_eff_out_rgb            ),

    .style_out_vsync            (style_out_vsync            ),
    .style_out_hsync            (style_out_hsync            ),
    .style_out_de               (style_out_de               ),
    .style_out_xcnt             (style_out_xcnt             ),
    .style_out_ycnt             (style_out_ycnt             ),
    .style_out_rgb              (style_out_rgb              )
);

VPU_SCALE_FILL VPU_SCALE_FILL(
    .clk                        (clk                        ),
    .reset                      (reset                      ),

    .enable                     (!vpu_scaler_disable        ),
    .src_w                      (vpu_valid_width            ),
    .src_h                      (vpu_valid_height           ),
    .dst_w                      (vpu_scaler_target_width    ),
    .dst_h                      (vpu_scaler_target_height   ),

    .in_vsync                   (vpu_in_vsync               ),
    .in_hsync                   (vpu_in_hsync               ),
    .in_de                      (vpu_in_de                  ),
    .in_xcnt                    (vpu_in_xcnt                ),
    .in_ycnt                    (vpu_in_ycnt                ),

    .cut_disable                (cut_to_disable             ),
    .cut_mode                   (cut_to_mode_set            ),
    .cut_speed                  (cut_to_speed_set           ),
    .cut_pchange                (vpu_in_pchange             ),
    .cut_active                 (cut_to_active              ),
    .cut_done                   (cut_to_out_done            ),

    .run                        (scale_run                  ),
    .flush                      (scale_flush                ),
    .line_req                   (scale_line_req             ),
    .line_y                     (scale_line_y               ),
    .line_bank                  (scale_line_bank            ),
    .line_pic                   (scale_line_pic             ),
    .line_ack                   (scale_line_ack             ),
    .pix_re                     (scale_pix_re               ),
    .pix_data                   (scale_pix_data             ),
    .pix_empty                  (scale_pix_empty            ),
    .pix_valid                  (scale_pix_valid            ),

    .out_vsync                  (fill_vsync                 ),
    .out_hsync                  (fill_hsync                 ),
    .out_de                     (fill_de                    ),
    .out_xcnt                   (fill_xcnt                  ),
    .out_ycnt                   (fill_ycnt                  ),
    .out_rgb                    (fill_rgb                   ),
    .out_src_w                  (                           ),
    .out_src_h                  (                           ),
    .out_dst_w                  (fill_dst_w                 ),
    .out_dst_h                  (fill_dst_h                 )
);

VPU_audio_wave VPU_audio_wave(
    .clk                        (clk                        ),
    .reset                      (reset                      ),

    .vpu_audio_disable          (vpu_audio_disable          ),
    .vpu_audio_mode             (vpu_audio_mode             ),
    .vpu_audio_color_mode       (vpu_audio_color_mode       ),
    .vpu_audio_color_data       (vpu_audio_color_data       ),
    .audio_wave_sx              (vpu_audio_sx               ),
    .audio_wave_sy              (vpu_audio_sy               ),

    .vpu_audio_valid            (vpu_audio_valid            ),
    .vpu_audio_data             (vpu_audio_data             ),

    .audio_wave_in_vsync        (style_out_vsync            ),
    .audio_wave_in_hsync        (style_out_hsync            ),
    .audio_wave_in_de           (style_out_de               ),
    .audio_wave_in_xcnt         (style_out_xcnt             ),
    .audio_wave_in_ycnt         (style_out_ycnt             ),
    .audio_wave_in_rgb          (style_out_rgb              ),

    .audio_wave_out_vsync       (audio_out_vsync            ),
    .audio_wave_out_hsync       (audio_out_hsync            ),
    .audio_wave_out_de          (audio_out_de               ),
    .audio_wave_out_xcnt        (audio_out_xcnt             ),
    .audio_wave_out_ycnt        (audio_out_ycnt             ),
    .audio_wave_out_rgb         (audio_out_rgb              )
);

VPU_OSD #(
    .LOGO_INIT_FILE             ("../sources/osd/osd_logo_128_init.mem"),
    .TXT_INIT_FILE              ("../sources/osd/osd_txt_init.mem")
)VPU_OSD(
    .clk                        (clk                        ),
    .reset                      (reset                      ),

    // .osd_valid_width            (vpu_valid_width            ),
    // .osd_valid_height           (vpu_valid_height           ),
    .osd_valid_width            (13'd1280                   ),
    .osd_valid_height           (13'd720                    ),
    .osd_disable                (osd_disable                ),

    .osd_logo_sx                (osd_logo_sx                ),
    .osd_logo_sy                (osd_logo_sy                ),
    
    .osd_txt_sx                 (osd_txt_sx                 ),
    .osd_txt_sy                 (osd_txt_sy                 ),
    .osd_txt_x_area             (osd_txt_x_area             ),
    .osd_txt_speed              (osd_txt_speed              ),
    .osd_color_mode             (osd_color_mode             ),
    .osd_color_set              (osd_color_set              ),

    .osd_txt_disable            (osd_txt_disable            ),
    .osd_txtram_dv              (osd_txtram_dv              ),
    .osd_txtram_data            (osd_txtram_data            ),
    .osd_txtram_addr            (osd_txtram_addr            ),

    // .osd_in_vsync               (audio_out_vsync            ),
    // .osd_in_hsync               (audio_out_hsync            ),
    // .osd_in_de                  (audio_out_de               ),
    // .osd_in_xcnt                (audio_out_xcnt             ),
    // .osd_in_ycnt                (audio_out_ycnt             ),
    // .osd_in_rgb                 (audio_out_rgb              ),
    .osd_in_vsync               (audio_out_vsync            ),
    .osd_in_hsync               (audio_out_hsync            ),
    .osd_in_de                  (audio_out_de               ),
    .osd_in_xcnt                (audio_out_xcnt             ),
    .osd_in_ycnt                (audio_out_ycnt             ),
    .osd_in_rgb                 (audio_out_rgb              ),

    .osd_out_vsync              (osd_out_vsync              ),
    .osd_out_hsync              (osd_out_hsync              ),
    .osd_out_de                 (osd_out_de                 ),
    .osd_out_xcnt               (osd_out_xcnt               ),
    .osd_out_ycnt               (osd_out_ycnt               ),
    .osd_out_rgb                (osd_out_rgb                )
);

VPU_MENU_OSD #(
    .INFOR_INIT_FILE            ("../sources/osd/osd_infor_init.mem")
)VPU_MENU_OSD(
    .clk                        (clk                        ),
    .reset                      (reset                      ),
    .menu_on                    (menu_on                    ),
    .menu_uart                  (menu_uart                  ),
    .menu_page                  (menu_page                  ),
    .menu_item                  (menu_item                  ),
    .menu_edit                  (menu_edit                  ),
    .cut_disable                (cut_to_disable             ),
    .cut_mode                   (cut_to_mode_set            ),
    .cut_speed                  (cut_to_speed_set           ),
    .color_disable              (dis_eff_disable            ),
    .lumi                       (lumi_set_data              ),
    .contrast                   (contrast_set_data          ),
    .temp                       (temp_set_data              ),
    .tint                       (tint_set_data              ),
    .style_disable              (style_disable              ),
    .style_mode                 (style_mode                 ),
    .style_th                   (style_bin_th               ),
    .style_gamma                (style_gamma                ),
    .osd_disable                (osd_disable                ),
    .logo_x                     (osd_logo_sx                ),
    .logo_y                     (osd_logo_sy                ),
    .txt_disable                (osd_txt_disable            ),
    .txt_x                      (osd_txt_sx                 ),
    .txt_y                      (osd_txt_sy                 ),
    .txt_w                      (osd_txt_x_area             ),
    .txt_speed                  (osd_txt_speed              ),
    .txt_cmode                  (osd_color_mode             ),
    .txt_color                  (osd_color_set              ),
    .aud_disable                (vpu_audio_disable          ),
    .aud_mode                   (vpu_audio_mode             ),
    .aud_cmode                  (vpu_audio_color_mode       ),
    .aud_color                  (vpu_audio_color_data       ),
    .aud_x                      (vpu_audio_sx               ),
    .aud_y                      (vpu_audio_sy               ),
    .scale_disable              (vpu_scaler_disable         ),
    .scale_w                    (vpu_scaler_target_width    ),
    .scale_h                    (vpu_scaler_target_height   ),
    .in_vsync                   (osd_out_vsync              ),
    .in_hsync                   (osd_out_hsync              ),
    .in_de                      (osd_out_de                 ),
    .in_x                       (osd_out_xcnt               ),
    .in_y                       (osd_out_ycnt               ),
    .in_rgb                     (osd_out_rgb                ),
    .out_vsync                  (vpu_out_vsync              ),
    .out_hsync                  (vpu_out_hsync              ),
    .out_de                     (vpu_out_de                 ),
    .out_x                      (vpu_out_xcnt               ),
    .out_y                      (vpu_out_ycnt               ),
    .out_rgb                    (vpu_out_rgb                )
);

assign vpu_cut_active   = cut_to_active;
assign vpu_cut_done_tog = cut_done_tog;
assign vpu_cut_disable  = cut_to_disable;
assign scale_want       = 1'b1;

always @(posedge clk) begin
    if(reset)
        cut_done_tog <= 1'b0;
    else if(cut_to_out_done)
        cut_done_tog <= ~cut_done_tog;
end

endmodule
