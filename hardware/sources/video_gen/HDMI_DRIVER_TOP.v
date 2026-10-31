

// 把 HDMI_MODE_SEL 传给 hdmi_driver。可选 "640x480@60"、"1280x720@60"、"1920x1080@30"、"1920x1080@60"。
// 1080p30 与 1080p60 行场相同：H 2200/44/88/148/1920，V 1125/5/4/36/1080。像素时钟 74.25 MHz。
// 像素不再从两路 SDRAM 整幅读进 FIFO。本模块只产生 VS/HS/DE/X/Y。
module HDMI_DRIVER_TOP #(
    parameter [127:0]           HDMI_MODE_SEL = "1920x1080@60"
)(
    input   wire                HDMI_CLK            ,  
    input   wire                RESET               ,
  
    input   wire                HDMI_INIT_DONE      ,
    input   wire                HDMI_BLACK_LOCKED   ,

    input   wire    [12:0]      HDMI_VALID_WIDTH    ,
    input   wire    [12:0]      HDMI_VALID_HEIGHT   ,

    input   wire                SDRAM_CLK           ,
    input   wire                SDRAM_P1_DV         ,
    input   wire    [23:0]      SDRAM_P1_DATA       ,
    input   wire                SDRAM_P2_DV         ,
    input   wire    [23:0]      SDRAM_P2_DATA       ,

    output  wire                HDMI_BUFFER1_REQ    ,
    input   wire                HDMI_FRAMER1_DONE   ,
    output  wire                HDMI_BUFFER2_REQ    ,
    input   wire                HDMI_FRAMER2_DONE   ,

    output  wire                O_HDMI_VSYNC        , 
    output  wire                O_HDMI_HSYNC        , 
    output  wire                O_HDMI_DE           , 
    output  wire    [12:0]      O_HDMI_XCNT         ,
    output  wire    [12:0]      O_HDMI_YCNT         ,
    output  wire    [23:0]      O_HDMI_RGB1         ,
    output  wire    [23:0]      O_HDMI_RGB2         
);

wire                            pixel_req           ;
wire    [12:0]                  pixel_xpos          ;
wire    [12:0]                  pixel_ypos          ;
wire                            head_flag           ;

reg     [12:0]                  pixel_xpos_r1       ;
reg     [12:0]                  pixel_xpos_r2       ;
reg     [12:0]                  pixel_ypos_r1       ;

assign HDMI_BUFFER1_REQ = 1'b0;
assign HDMI_BUFFER2_REQ = 1'b0;
assign O_HDMI_RGB1 = 24'd0;
assign O_HDMI_RGB2 = 24'd0;

hdmi_driver #(
    .HDMI_MODE_SEL  ( HDMI_MODE_SEL     )
) hdmi_driver(
    .pixel_clk      (HDMI_CLK           ),
    .reset          (RESET              ),
		
    .o_hdmi_hs      (O_HDMI_HSYNC       ), 
    .o_hdmi_vs      (O_HDMI_VSYNC       ), 
    .o_hdmi_de      (O_HDMI_DE          ), 
    .o_hdmi_rgb     (                   ), 

    .pixel_req      (pixel_req          ),
    .pixel_xpos     (pixel_xpos         ),
    .pixel_ypos     (pixel_ypos         ),
    .pixel_data     (                   ),

    .head_flag      (head_flag          ),
    .new_flag       (                   )
);

always@(posedge HDMI_CLK) begin
    pixel_xpos_r1 <= pixel_xpos;
    // 时序对齐：hdmi_driver 的 DE 在 pixel_req 之后打了两拍，
    // pixel_xpos 只跟 pixel_req 对齐。X 只延迟一拍时，有效区第一个点的
    // x 是 1。缩放器用 x==0 锁一行，写不进行缓存。Y 已经和 DE 对齐。
    pixel_xpos_r2 <= pixel_xpos_r1;
    pixel_ypos_r1 <= pixel_ypos;
end

assign O_HDMI_XCNT = pixel_xpos_r2;
assign O_HDMI_YCNT = pixel_ypos_r1;

endmodule
