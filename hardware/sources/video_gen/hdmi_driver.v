// HDMI_MODE_SEL 由上级例化传入，字符串按 128 bit 右侧对齐。
//   "640x480@60"    H 800/96/16/48/640     V 525/2/10/33/480
//   "1280x720@60"   H 1650/40/110/220/1280 V 750/5/5/20/720
//   "1920x1080@30"  H 2200/44/88/148/1920  V 1125/5/4/36/1080
//   "1920x1080@60"  H 2200/44/88/148/1920  V 1125/5/4/36/1080
module hdmi_driver #(
    parameter [127:0]           HDMI_MODE_SEL = "1280x720@60"
)(
    input   wire                pixel_clk   ,
    input   wire                reset       ,

    output  reg                 o_hdmi_hs   , 
    output  reg                 o_hdmi_vs   , 
    output  reg                 o_hdmi_de   , 
    output  reg     [23:0]      o_hdmi_rgb  , 

    output	reg                 pixel_req   ,
    output  reg     [12:0]      pixel_xpos  ,
    output  reg     [12:0]      pixel_ypos  ,
    input   wire    [23:0]      pixel_data  ,

    output  reg                 head_flag   ,
    output  reg                 new_flag    
);


localparam [127:0] HDMI_MODE_640x480_60   = "640x480@60";
localparam [127:0] HDMI_MODE_1280x720_60  = "1280x720@60";
localparam [127:0] HDMI_MODE_1920x1080_30 = "1920x1080@30";
localparam [127:0] HDMI_MODE_1920x1080_60 = "1920x1080@60";

localparam integer HDMI_HSA =
    (HDMI_MODE_SEL == HDMI_MODE_640x480_60)   ? 96  :
    (HDMI_MODE_SEL == HDMI_MODE_1280x720_60)  ? 40  :
    (HDMI_MODE_SEL == HDMI_MODE_1920x1080_30) ? 44  :
    (HDMI_MODE_SEL == HDMI_MODE_1920x1080_60) ? 44  : 0;
localparam integer HDMI_HBP =
    (HDMI_MODE_SEL == HDMI_MODE_640x480_60)   ? 48  :
    (HDMI_MODE_SEL == HDMI_MODE_1280x720_60)  ? 220 :
    (HDMI_MODE_SEL == HDMI_MODE_1920x1080_30) ? 148 :
    (HDMI_MODE_SEL == HDMI_MODE_1920x1080_60) ? 148 : 0;
localparam integer HDMI_HACTIVE =
    (HDMI_MODE_SEL == HDMI_MODE_640x480_60)   ? 640  :
    (HDMI_MODE_SEL == HDMI_MODE_1280x720_60)  ? 1280 :
    (HDMI_MODE_SEL == HDMI_MODE_1920x1080_30) ? 1920 :
    (HDMI_MODE_SEL == HDMI_MODE_1920x1080_60) ? 1920 : 0;
localparam integer HDMI_HFP =
    (HDMI_MODE_SEL == HDMI_MODE_640x480_60)   ? 16  :
    (HDMI_MODE_SEL == HDMI_MODE_1280x720_60)  ? 110 :
    (HDMI_MODE_SEL == HDMI_MODE_1920x1080_30) ? 88  :
    (HDMI_MODE_SEL == HDMI_MODE_1920x1080_60) ? 88  : 0;
localparam integer HDMI_HTOTAL =
    (HDMI_MODE_SEL == HDMI_MODE_640x480_60)   ? 800  :
    (HDMI_MODE_SEL == HDMI_MODE_1280x720_60)  ? 1650 :
    (HDMI_MODE_SEL == HDMI_MODE_1920x1080_30) ? 2200 :
    (HDMI_MODE_SEL == HDMI_MODE_1920x1080_60) ? 2200 : 0;
localparam integer HDMI_VSA =
    (HDMI_MODE_SEL == HDMI_MODE_640x480_60)   ? 2 :
    (HDMI_MODE_SEL == HDMI_MODE_1280x720_60)  ? 5 :
    (HDMI_MODE_SEL == HDMI_MODE_1920x1080_30) ? 5 :
    (HDMI_MODE_SEL == HDMI_MODE_1920x1080_60) ? 5 : 0;
localparam integer HDMI_VBP =
    (HDMI_MODE_SEL == HDMI_MODE_640x480_60)   ? 33 :
    (HDMI_MODE_SEL == HDMI_MODE_1280x720_60)  ? 20 :
    (HDMI_MODE_SEL == HDMI_MODE_1920x1080_30) ? 36 :
    (HDMI_MODE_SEL == HDMI_MODE_1920x1080_60) ? 36 : 0;
localparam integer HDMI_VACTIVE =
    (HDMI_MODE_SEL == HDMI_MODE_640x480_60)   ? 480  :
    (HDMI_MODE_SEL == HDMI_MODE_1280x720_60)  ? 720  :
    (HDMI_MODE_SEL == HDMI_MODE_1920x1080_30) ? 1080 :
    (HDMI_MODE_SEL == HDMI_MODE_1920x1080_60) ? 1080 : 0;
localparam integer HDMI_VFP =
    (HDMI_MODE_SEL == HDMI_MODE_640x480_60)   ? 10 :
    (HDMI_MODE_SEL == HDMI_MODE_1280x720_60)  ? 5  :
    (HDMI_MODE_SEL == HDMI_MODE_1920x1080_30) ? 4  :
    (HDMI_MODE_SEL == HDMI_MODE_1920x1080_60) ? 4  : 0;
localparam integer HDMI_VTOTAL =
    (HDMI_MODE_SEL == HDMI_MODE_640x480_60)   ? 525  :
    (HDMI_MODE_SEL == HDMI_MODE_1280x720_60)  ? 750  :
    (HDMI_MODE_SEL == HDMI_MODE_1920x1080_30) ? 1125 :
    (HDMI_MODE_SEL == HDMI_MODE_1920x1080_60) ? 1125 : 0;

parameter   H_SYNC   =  HDMI_HSA;
parameter   H_BACK   =  HDMI_HBP;
parameter   H_DISP   =  HDMI_HACTIVE;
parameter   H_FRONT  =  HDMI_HFP;
parameter   H_TOTAL  =  HDMI_HTOTAL;

// 仿真只把场消隐改成同步 2 行、后沿 3 行，前沿补满，总行数和有效行数不变。
`ifdef SIM_MODE
parameter   V_SYNC   =  12'd2;
parameter   V_BACK   =  12'd3;
parameter   V_DISP   =  HDMI_VACTIVE;
parameter   V_TOTAL  =  HDMI_VTOTAL;
parameter   V_FRONT  =  HDMI_VTOTAL - HDMI_VACTIVE - 5;
`else
parameter   V_SYNC   =  HDMI_VSA;
parameter   V_BACK   =  HDMI_VBP;
parameter   V_DISP   =  HDMI_VACTIVE;
parameter   V_FRONT  =  HDMI_VFP;
parameter   V_TOTAL  =  HDMI_VTOTAL;
`endif

generate
    if (HDMI_HTOTAL == 0) begin : gen_hdmi_mode_error
        illegal_hdmi_video_mode unsupported();
    end
endgenerate

parameter   START_V_CNT = V_SYNC + V_BACK;
parameter   START_H_CNT = H_SYNC + H_BACK;

parameter   END_V_CNT = V_SYNC + V_BACK + V_DISP;
parameter   END_H_CNT = H_SYNC + H_BACK + H_DISP;
//reg define
reg     [12:0]      cnt_h       ;
reg     [12:0]      cnt_v       ;
reg                 video_en    ;




wire                video_hs    ;
wire                video_vs    ;
wire                video_de    ;
wire    [23:0]      video_rgb   ;

//*****************************************************
//**                    main code
//*****************************************************

assign video_de  = video_en;
assign video_hs  = ( cnt_h < H_SYNC ) ? 1'b0 : 1'b1;  
assign video_vs  = ( cnt_v < V_SYNC ) ? 1'b0 : 1'b1;  

assign video_rgb = video_de ? pixel_data : 24'd0; 


always@(posedge pixel_clk) begin
	if(reset) begin
		video_en <= 1'b0;
    end
	else begin
		video_en <= pixel_req;
    end
end


always@(posedge pixel_clk) begin
	if(reset) begin
		pixel_req <= 1'b0;
    end
	else if(((cnt_h >= H_SYNC + H_BACK - 2'd2) && (cnt_h < H_SYNC + H_BACK + H_DISP - 2'd2))
                  && ((cnt_v >= V_SYNC + V_BACK) && (cnt_v < V_SYNC + V_BACK+V_DISP))) begin
		pixel_req <= 1'b1;
    end
	else begin
		pixel_req <= 1'b0;
    end
end


always@(posedge pixel_clk) begin
    if(reset) begin
        pixel_xpos <= 13'd0;
    end
    else if(pixel_req) begin
        pixel_xpos <= cnt_h + 2'd2 - H_SYNC - H_BACK ;
    end
    else begin
        pixel_xpos <= 13'd0;
    end
end
    

always@(posedge pixel_clk) begin
    if(reset) begin
        pixel_ypos <= 13'd0;
    end
    else if((cnt_v >= (V_SYNC + V_BACK)) && (cnt_v < (V_SYNC + V_BACK + V_DISP))) begin
        pixel_ypos <= cnt_v + 1'b1 - (V_SYNC + V_BACK) ;
    end
    else begin
        pixel_ypos <= 13'd0;
    end
end


always@(posedge pixel_clk) begin
    if(reset) begin
        cnt_h <= 13'd0;
    end
    else begin
        if(cnt_h < H_TOTAL - 1'b1) begin
            cnt_h <= cnt_h + 1'b1;
        end
        else begin
            cnt_h <= 13'd0;
        end
    end
end


always@(posedge pixel_clk) begin
    if(reset) begin
    `ifdef SIM_MODE
        cnt_v <= V_TOTAL - 13'd14;
    `else 
        cnt_v <= 13'd0;
    `endif 
    end
    else if(cnt_h == H_TOTAL - 1'b1) begin
        if(cnt_v < V_TOTAL - 1'b1) begin
            cnt_v <= cnt_v + 1'b1;
        end
        else begin
            cnt_v <= 13'd0;
        end
    end
end


always@(posedge pixel_clk) begin
    if(reset) begin
        head_flag <= 1'b0;
    end
    // else if(cnt_v == V_SYNC && cnt_h == H_SYNC) begin
    else if(cnt_v == 13'd2 && cnt_h == H_SYNC) begin
        head_flag <= 1'b1;
    end
    else begin
        head_flag <= 1'b0;
    end 
end

always@(posedge pixel_clk) begin
    if(reset) begin
        new_flag <= 1'b0;
    end
    else if((cnt_v >= START_V_CNT - 13'd1) && (cnt_v <= END_V_CNT - 13'd2) && cnt_h == H_SYNC) begin
        new_flag <= 1'b1;
    end
    else begin
        new_flag <= 1'b0;
    end 
end





always@(posedge pixel_clk) begin
    o_hdmi_hs   <= !video_hs    ;
    o_hdmi_vs   <= !video_vs    ;
    o_hdmi_de   <= video_de     ;
    o_hdmi_rgb  <= video_rgb    ;    
end




endmodule