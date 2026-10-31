`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Create Date: 2026/10/11 09:21:17
// Module Name: SDCARD_BMP_READ
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


module SDCARD_BMP_READ #(
    parameter                   CLK_FREQ                    = 50_000_000
)(
    input   wire                clk                         ,
    input   wire                reset                       ,

    input   wire                sd_index_init_done          ,

    input   wire                sd_bmp_init_flag            ,
    output  reg                 sd_bmp_init_done            ,

    input   wire                sd_bmp_Structures_flag      ,
    input   wire    [3:0]       sd_bmp_Structures_cnt       ,
    input   wire    [81:0]      sd_bmp_Structures_data      ,//24+32+13+13

    output  reg                 sd_bmp_r_req                ,
    output  reg     [31:0]      sd_bmp_r_addr               ,
    input   wire                sd_bmp_r_ack                ,

    input   wire                sd_bmp_r_start              ,
    input   wire                sd_bmp_r_dv                 ,
    input   wire    [7:0]       sd_bmp_r_data               ,
    input   wire                sd_bmp_r_end                ,
    input   wire    [8:0]       sd_bmp_r_cnt                ,
    input   wire                sd_bmp_r_err                ,

    output  reg                 sd_bmp_out_start            ,
    output  reg     [3:0]       sd_bmp_out_index            ,
    output  reg     [12:0]      sd_bmp_out_width            ,
    output  reg     [12:0]      sd_bmp_out_height           ,
    output  reg                 sd_bmp_out_dv               ,
    output  reg     [23:0]      sd_bmp_out_data             ,
    output  reg     [12:0]      sd_bmp_out_xcnt             ,
    output  reg     [12:0]      sd_bmp_out_ycnt             
);

reg                             sd_index_init_done_r        ;
reg                             sd_bmp_init_flag_r          ;

reg                             sdpram_cmd_wea              ;
reg     [81:0]                  sdpram_cmd_dina             ;
reg     [3:0]                   sdpram_cmd_addra            ;
reg     [3:0]                   sdpram_cmd_addrb            ;
wire    [81:0]                  sdpram_cmd_doutb            ;
reg     [81:0]                  sdpram_cmd_doutb_r          ;

wire                            sdpram_cmd_rd_en            ;
reg                             sdpram_cmd_rd_en_r          ;
reg                             sdpram_cmd_rd_en_rr         ;

reg     [3:0]                   sdpram_cmd_addr_end         ;

reg                             sdpram_cmd_nempty           ;
reg                             sdpram_cmd_nempty_r         ;
wire                            sdpram_cmd_nempty_pos       ;
reg     [3:0]                   sdpram_cmd_nempty_pos_r4    ;

reg     [23:0]                  type_bmp_saddr              ;
reg     [31:0]                  type_bmp_blength            ;
reg     [12:0]                  type_bmp_width              ;
reg     [12:0]                  type_bmp_height             ;

reg                             bmp_start                   ;
reg                             bmp_dv                      ;
reg     [7:0]                   bmp_data                    ;
reg                             bmp_end                     ;
reg     [8:0]                   bmp_cnt                     ;
reg                             bmp_err                     ;

/*----------------------------------------------------------*/

reg                             bmp_read_sop                ;
reg                             bmp_read_hold               ;
reg                             bmp_read_eop                ;

reg                             bmp_read_req_start          ;

reg     [22:0]                  bmp_read_section_nub        ;
reg     [22:0]                  bmp_read_section_cnt        ;

/*----------------------------------------------------------*/

parameter                       STA_IDLE                    = 3'd0  ,
                                STA_REQ                     = 3'd1  ,
                                STA_DATA                    = 3'd2  ,
                                STA_DONE                    = 3'd3  ,
                                STA_ERR                     = 3'd4  ;

reg     [2:0]                   state                       ;
reg     [2:0]                   state_r                     ;
reg     [2:0]                   state_rr                    ;

reg                             state_change_flag           ;

reg     [5:0]                   bmp_read_head_cnt           ;
reg     [31:0]                  bmp_read_payload_cnt        ;

reg                             bmp_read_head_dv            ;
reg     [7:0]                   bmp_read_head_data          ;

reg                             bmp_read_payload_hold       ;
reg                             bmp_read_payload_dv         ;
reg     [7:0]                   bmp_read_payload_data       ;

always@(posedge clk) begin
    sd_index_init_done_r    <= sd_index_init_done   ;
    sd_bmp_init_flag_r      <= sd_bmp_init_flag     ;

    bmp_start   <= sd_bmp_r_start   ;
    bmp_dv      <= sd_bmp_r_dv      ;
    bmp_data    <= sd_bmp_r_data    ;
    bmp_end     <= sd_bmp_r_end     ;
    bmp_cnt     <= sd_bmp_r_cnt     ;
    bmp_err     <= sd_bmp_r_err     ;
end



always@(posedge clk) begin
    if(reset) begin
        sdpram_cmd_nempty <= 1'b0;
    end
    else if(bmp_read_eop) begin
        sdpram_cmd_nempty <= 1'b0;
    end
    else if(!sdpram_cmd_nempty && sd_index_init_done_r && sdpram_cmd_addrb != sdpram_cmd_addr_end) begin
        sdpram_cmd_nempty <= 1'b1;
    end
    sdpram_cmd_nempty_r <= sdpram_cmd_nempty;

    sdpram_cmd_nempty_pos_r4 <= {sdpram_cmd_nempty_pos_r4[2:0],sdpram_cmd_nempty_pos};
end

assign sdpram_cmd_nempty_pos = sdpram_cmd_nempty & !sdpram_cmd_nempty_r;


always@(posedge clk) begin
    type_bmp_saddr     <= sdpram_cmd_rd_en_rr ? sdpram_cmd_doutb_r[81:58] : type_bmp_saddr        ;
    type_bmp_blength   <= sdpram_cmd_rd_en_rr ? sdpram_cmd_doutb_r[57:26] : type_bmp_blength      ;
    type_bmp_width     <= sdpram_cmd_rd_en_rr ? sdpram_cmd_doutb_r[25:13] : type_bmp_width        ;
    type_bmp_height    <= sdpram_cmd_rd_en_rr ? sdpram_cmd_doutb_r[12:0]  : type_bmp_height       ;
end

always@(posedge clk) begin

    bmp_read_sop <= sdpram_cmd_nempty_pos_r4[1];

    if(reset) begin
        bmp_read_hold <= 1'b0;
    end
    else if(bmp_read_eop) begin
        bmp_read_hold <= 1'b0;
    end
    else if(bmp_read_sop) begin
        bmp_read_hold <= 1'b1;
    end

    bmp_read_eop <= bmp_read_hold && bmp_read_section_cnt == bmp_read_section_nub - 1'b1 && bmp_end;
end

always@(posedge clk) begin
    if(type_bmp_blength[8:0] == 9'd0) begin
        bmp_read_section_nub <= type_bmp_blength[31:9];
    end
    else if(type_bmp_blength[8:0] != 9'd0) begin
        bmp_read_section_nub <= type_bmp_blength[31:9] + 1'b1;
    end
end

always@(posedge clk) begin
    if(reset) begin
        bmp_read_section_cnt <= 23'd0;
    end
    else if(bmp_read_eop) begin
        bmp_read_section_cnt <= 23'd0;
    end
    else if(bmp_read_hold && bmp_end) begin
        bmp_read_section_cnt <= bmp_read_section_cnt + 1'b1;
    end
end

always@(posedge clk) begin
    if(bmp_read_sop) begin
        bmp_read_req_start <= 1'b1;
    end
    else if(bmp_read_hold && bmp_read_section_cnt < bmp_read_section_nub && state == STA_DONE) begin
        bmp_read_req_start <= 1'b1;
    end
    else begin
        bmp_read_req_start <= 1'b0;
    end
end

always@(posedge clk) begin
    if(reset) begin
        state <= STA_IDLE;
    end
    else begin
        case(state)
            STA_IDLE    : begin 
                if(bmp_read_req_start) begin 
                    state <= STA_REQ;
                end 
            end
            STA_REQ     : begin if(sd_bmp_r_ack)             begin state <= STA_DATA     ;end end
            STA_DATA    : begin if(bmp_read_hold && bmp_end) begin state <= STA_DONE     ;end end
            STA_DONE    : begin                                    state <= STA_IDLE     ;end
            default     : begin                                    state <= STA_IDLE     ;end
        endcase
    end

    state_r <= state;
    state_rr <= state_r;

    state_change_flag <= state_rr != state_r;
end

always@(posedge clk) begin
    if(reset) begin
        sd_bmp_r_req <= 1'b0;
    end
    else if(sd_bmp_r_ack) begin
        sd_bmp_r_req <= 1'b0;
    end
    else if(bmp_read_req_start) begin
        sd_bmp_r_req <= 1'b1;
    end
end

always@(posedge clk) begin
    if(reset) begin
        sd_bmp_r_addr <= 32'd0;
    end
    else if(bmp_read_sop) begin
        sd_bmp_r_addr <= {8'd0,type_bmp_saddr};
    end
    else if(bmp_read_hold && bmp_end) begin
        sd_bmp_r_addr <= sd_bmp_r_addr + 1'b1;
    end
end

/*----------------------------------------------------------*/

always@(posedge clk) begin
    if(sd_bmp_Structures_flag) begin
        sdpram_cmd_dina     <= sd_bmp_Structures_data;
        sdpram_cmd_wea      <= 1'b1;
        sdpram_cmd_addra    <= sd_bmp_Structures_cnt;
    end
    else begin
        sdpram_cmd_wea      <= 1'b0;
    end
end


assign sdpram_cmd_rd_en = sdpram_cmd_nempty_pos;

always@(posedge clk) begin
    sdpram_cmd_rd_en_r  <= sdpram_cmd_rd_en;
    sdpram_cmd_rd_en_rr <= sdpram_cmd_rd_en_r;
    sdpram_cmd_doutb_r  <= sdpram_cmd_doutb;
end

// 16 条 82 位图片结构。读延迟 1 拍，和原来的寄存器读出对齐。
simple_dual_ram #(
    .RAM_WIDTH                  (82                         ),
    .RAM_DEPTH                  (16                         ),
    .PERFORMENCE                ("LOW"                      ),
    .INIT_FILE                  (""                         )
)sdpram_cmd(
    .clka                       (clk                        ),
    .wea                        (sdpram_cmd_wea             ),
    .dina                       (sdpram_cmd_dina            ),
    .addra                      (sdpram_cmd_addra           ),
    .addrb                      (sdpram_cmd_addrb           ),
    .doutb                      (sdpram_cmd_doutb           )
);

always@(posedge clk) begin
    if(reset) begin
        sdpram_cmd_addr_end <= 4'd8;
    end
    else if(sd_bmp_init_flag_r && sd_bmp_init_done == 1'b1) begin
        sdpram_cmd_addr_end <= sdpram_cmd_addr_end + 4'd8;
    end
end

always@(posedge clk) begin
    if(reset) begin
        sdpram_cmd_addrb <= 4'd0;
    end
    else if(sdpram_cmd_rd_en) begin
        sdpram_cmd_addrb <= sdpram_cmd_addrb + 1'b1;
    end
end

/*----------------------------------------------------------*/

always@(posedge clk) begin
    if(bmp_read_sop) begin
        bmp_read_head_cnt <= 6'd0;
    end
    else if(bmp_read_hold && bmp_dv && bmp_read_head_cnt < 6'd54) begin
        bmp_read_head_cnt <= bmp_read_head_cnt + 1'b1;
    end
end

always@(posedge clk) begin
    if(bmp_read_sop) begin
        bmp_read_payload_cnt <= 32'd0;
    end
    else if(bmp_read_hold && bmp_dv && bmp_read_head_cnt == 6'd54) begin
        bmp_read_payload_cnt <= bmp_read_payload_cnt + 1'b1;
    end
end

/*----------------------------------------------------------*/

always@(posedge clk) begin
    if(bmp_read_sop) begin
        bmp_read_payload_hold <= 1'b0;
    end
    else if(bmp_read_hold && bmp_dv && bmp_read_payload_cnt == type_bmp_blength - 6'd54 - 1'b1) begin
        bmp_read_payload_hold <= 1'b0;
    end
    else if(bmp_read_hold && bmp_dv && bmp_read_head_cnt == 6'd53) begin
        bmp_read_payload_hold <= 1'b1;
    end
end

always@(posedge clk) begin
    if(bmp_read_payload_hold && bmp_dv) begin
        bmp_read_payload_dv <= 1'b1;
        bmp_read_payload_data <= bmp_data;
    end
    else begin
        bmp_read_payload_dv <= 1'b0;
    end
end



/*----------------------------------------------------------*/

reg     [1:0]                   bmp_read_bgr_cnt            ;
reg                             bmp_read_pixel_dv           ;
reg     [23:0]                  bmp_read_pixel_data         ;
reg     [12:0]                  bmp_read_pixel_x_cnt        ;
reg     [12:0]                  bmp_read_pixel_y_cnt        ;

always@(posedge clk) begin
    if(bmp_read_sop) begin
        bmp_read_bgr_cnt <= 2'd0;
    end
    if(bmp_read_payload_dv && bmp_read_bgr_cnt == 2'd2) begin
        bmp_read_bgr_cnt <= 2'd0;
    end
    else if(bmp_read_payload_dv) begin
        bmp_read_bgr_cnt <= bmp_read_bgr_cnt + 1'b1;
    end
end

always@(posedge clk) begin
    if(bmp_read_payload_dv && bmp_read_bgr_cnt == 2'd0) begin
        bmp_read_pixel_data[8*0+:8] <= bmp_read_payload_data;
    end
    else if(bmp_read_payload_dv && bmp_read_bgr_cnt == 2'd1) begin
        bmp_read_pixel_data[8*1+:8] <= bmp_read_payload_data;
    end
    else if(bmp_read_payload_dv && bmp_read_bgr_cnt == 2'd2) begin
        bmp_read_pixel_data[8*2+:8] <= bmp_read_payload_data;
    end

    bmp_read_pixel_dv <= bmp_read_payload_dv && bmp_read_bgr_cnt == 2'd2;
end

always@(posedge clk) begin
    if(bmp_read_sop) begin
        bmp_read_pixel_x_cnt <= 13'd0;
    end
    if(bmp_read_pixel_dv && bmp_read_pixel_x_cnt == type_bmp_width - 1'b1) begin
        bmp_read_pixel_x_cnt <= 13'd0;
    end
    else if(bmp_read_pixel_dv) begin
        bmp_read_pixel_x_cnt <= bmp_read_pixel_x_cnt + 1'b1;
    end
end

always@(posedge clk) begin
    if(bmp_read_sop) begin
        bmp_read_pixel_y_cnt <= 13'd0;
    end
    if(bmp_read_pixel_dv && bmp_read_pixel_x_cnt == type_bmp_width - 1'b1 && bmp_read_pixel_y_cnt == type_bmp_height - 1'b1) begin
        bmp_read_pixel_y_cnt <= 13'd0;
    end
    else if(bmp_read_pixel_dv && bmp_read_pixel_x_cnt == type_bmp_width - 1'b1) begin
        bmp_read_pixel_y_cnt <= bmp_read_pixel_y_cnt + 1'b1;
    end
end

/*----------------------------------------------------------*/
`ifndef SIM_MODE
always@(posedge clk) begin
    if(reset) begin
        sd_bmp_init_done    <= 1'b0;
    end
    else if(!sd_index_init_done_r || sd_bmp_init_flag_r) begin
        sd_bmp_init_done    <= 1'b0;
    end
    else if(bmp_read_eop && sdpram_cmd_addrb == sdpram_cmd_addr_end) begin
        sd_bmp_init_done    <= 1'b1;
    end
end

`else
always@(posedge clk) begin
    if(reset) begin
        sd_bmp_init_done    <= 1'b0;
    end
    else if(!sd_index_init_done_r || sd_bmp_init_flag_r) begin
        sd_bmp_init_done    <= 1'b0;
    end 
    else if(bmp_read_eop && sdpram_cmd_addrb == sdpram_cmd_addr_end) begin
        sd_bmp_init_done    <= 1'b1;
    end
end

`endif 

always@(posedge clk) begin
    sd_bmp_out_start    <= bmp_read_sop;
    if(reset) begin
        sd_bmp_out_index    <= 4'd0;
        sd_bmp_out_width    <= 13'd0;
        sd_bmp_out_height   <= 13'd0;
    end
    else if(bmp_read_sop) begin
        sd_bmp_out_index    <= sdpram_cmd_addrb - 1'b1;
        sd_bmp_out_width    <= type_bmp_width;
        sd_bmp_out_height   <= type_bmp_height;
    end
end

always@(posedge clk) begin
    sd_bmp_out_dv       <= bmp_read_pixel_dv;
    sd_bmp_out_data     <= bmp_read_pixel_data;
    sd_bmp_out_xcnt     <= bmp_read_pixel_x_cnt;
    sd_bmp_out_ycnt     <= bmp_read_pixel_y_cnt;
end




endmodule
