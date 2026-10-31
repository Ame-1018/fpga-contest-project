`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// ███╗   ███╗██╗   ██╗██╗  ██╗ █████╗ ███╗   ██╗
// ████╗ ████║██║   ██║██║  ██║██╔══██╗████╗  ██║
// ██╔████╔██║██║   ██║███████║███████║██╔██╗ ██║
// ██║╚██╔╝██║██║   ██║██╔══██║██╔══██║██║╚██╗██║
// ██║ ╚═╝ ██║╚██████╔╝██║  ██║██║  ██║██║ ╚████║
// ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝
// Create Date: 2026/10/08 09:21:17
// Design Name: 
// Module Name: EG4_SDRAM_RD_CTRL
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

module EG4_SDRAM_RD_CTRL(
    input   wire                clk                         ,
    input   wire                reset                       ,

    input   wire                sdram_bmp_init_done         ,
    input   wire    [2:0]       sdram_bmp_index             ,
    input   wire    [12:0]      sdram_bmp_width             ,
    input   wire    [12:0]      sdram_bmp_height            ,

    input   wire                sdram_clk                   ,

    input   wire                hdmi_driver_buf_vsync       ,
    input   wire                hdmi_driver_buf_req         ,
    output  reg                 hdmi_driver_buf_done        ,

    input   wire                Sdr_init_done               ,
    input   wire                Sdr_init_ref_vld            ,
    input   wire                Sdr_ref_hold                ,

    output  reg                 arbit_req                   ,
    output  reg                 arbit_end                   ,
    input   wire                arbit_allow                 ,

    output  reg                 App_rd_en                   ,
    output  reg     [20:0]      App_rd_addr                 ,
    input   wire                Sdr_rd_en                   ,
    input   wire    [31:0]      Sdr_rd_dout                 ,

    output  reg                 sdram_rd_pixel_dv           ,
    output  reg     [23:0]      sdram_rd_pixel_data         
);

/*----------------------------------------------------------*/
reg                             sdram_bmp_init_done_r       ;
reg     [2:0]                   sdram_bmp_index_ale         ;
reg     [12:0]                  sdram_bmp_width_ale         ;
reg     [12:0]                  sdram_bmp_height_ale        ;

reg     [12:0]                  rsdram_burst_row_length     ;
reg     [12:0]                  row_len_m1                  ;
reg     [12:0]                  rsdram_burst_row_cnt        ;
reg     [12:0]                  rsdram_burst_col_length     ;
reg     [12:0]                  col_len_m1                  ;
reg     [12:0]                  rsdram_burst_col_cnt        ;

/*----------------------------------------------------------*/

reg     [2:0]                   hdmi_vsync_r3               ;
reg     [7:0]                   hdmi_vsync_pos_r8           ;
reg     [7:0]                   hdmi_vsync_neg_r8           ;

reg                             hdmi_driver_buf_req_r       ;

reg                             Sdr_init_done_r             ;  

reg                             sdram_rd_picture_sop        ;
reg                             sdram_rd_picture_hold       ;
wire                            sdram_rd_picture_eop        ;

reg     [2:0]                   arbit_allow_r3              ;
wire                            arbit_allow_pos             ;

reg                             sdram_rd_burst_sop          ;
reg                             sdram_rd_burst_hold         ;
wire                            sdram_rd_burst_eop          ;
reg     [2:0]                   sdram_rd_burst_eop_r3       ;

reg                             sdram_rd_en                 ;
reg     [17:0]                  sdram_rd_addr               ;

reg                             Sdr_rd_en_r1                ;
reg     [31:0]                  Sdr_rd_dout_r1              ;

wire                            Sdr_rd_en_eop               ;

reg     [31:0]                  sfifo_din                   ;
reg                             sfifo_wr_en                 ;
wire                            sfifo_rd_en                 ;
wire    [31:0]                  sfifo_dout                  ;
wire                            sfifo_full                  ;
wire                            sfifo_empty                 ;
wire    [8:0]                   sfifo_count                 ;

reg                             sfifo_read_sop              ;
wire                            sfifo_read_eop              ;
reg                             sfifo_read_hold             ;
reg     [12:0]                  sfifo_read_cnt              ;
reg     [12:0]                  cnt_before_last             ;
reg                             read_at_last                ;
reg                             sfifo_read_hold_r           ;
reg                             sfifo_read_hold_rr          ;
reg     [11:0]                  sfifo_read_eop_r12          ;

reg                             sfifo_out_dv                ;
reg     [31:0]                  sfifo_out_data              ;
reg     [12:0]                  sfifo_out_cnt               ;
reg     [1:0]                   sfifo_out_cnt3              ;

reg     [2:0]                   sfifo_out_dv_r3             ;

reg     [31:0]                  sfifo_out_data_r1           ;
reg     [31:0]                  sfifo_out_data_r2           ;

reg                             sfifo_out_ale_flag          ;
reg                             sfifo_out_ale_hold          ;
reg     [1:0]                   sfifo_out_ale_cnt           ;
reg     [31:0]                  sfifo_out_rrrr_ale          ;
reg     [31:0]                  sfifo_out_gggg_ale          ;
reg     [31:0]                  sfifo_out_bbbb_ale          ;

reg                             sfifo_out_pixel_dv          ;
reg     [23:0]                  sfifo_out_pixel_data        ;
/*----------------------------------------------------------*/

always@(posedge sdram_clk) begin
    if(hdmi_vsync_pos_r8[5]) begin
        sdram_bmp_init_done_r   <= sdram_bmp_init_done  ;
        sdram_bmp_index_ale     <= sdram_bmp_index      ;
        sdram_bmp_width_ale     <= sdram_bmp_width      ;
        sdram_bmp_height_ale    <= sdram_bmp_height     ;
    end
end

always@(posedge sdram_clk) begin
    if(hdmi_vsync_pos_r8[6]) begin
        rsdram_burst_row_length <= sdram_bmp_height_ale;
        rsdram_burst_col_length <= sdram_bmp_width_ale[12:2] + (sdram_bmp_width_ale[12:2] << 1);
    end
end

// 时序：150 MHz 建立时间违例在长度减 1 再和计数比较，slack -0.515ns。
// 减 1 提前打一拍。长度在场同步后才变，突发进行中用的是同一帧的终点。
always@(posedge sdram_clk) begin
    col_len_m1 <= rsdram_burst_col_length - 13'd1;
    row_len_m1 <= rsdram_burst_row_length - 13'd1;
end

/*----------------------------------------------------------*/

always@(posedge sdram_clk) begin
    hdmi_vsync_r3 <= {hdmi_vsync_r3[1:0],hdmi_driver_buf_vsync};
    hdmi_vsync_pos_r8 <= {hdmi_vsync_pos_r8[6:0],hdmi_vsync_r3[0] & !hdmi_vsync_r3[1]};
    hdmi_vsync_neg_r8 <= {hdmi_vsync_neg_r8[6:0],!hdmi_vsync_r3[0] & hdmi_vsync_r3[1]};
end

always@(posedge sdram_clk) begin
    hdmi_driver_buf_req_r   <= hdmi_driver_buf_req      ;
end

always@(posedge sdram_clk) begin
    Sdr_init_done_r         <= Sdr_init_done            ;    
end


always@(posedge sdram_clk) begin
    sdram_rd_picture_sop <= hdmi_vsync_pos_r8[7] & sdram_bmp_init_done_r == 1'b1 & Sdr_init_done_r;

    if(reset) begin
        sdram_rd_picture_hold <= 1'b0;
    end
    else if(sdram_rd_picture_eop) begin
        sdram_rd_picture_hold <= 1'b0;
    end
    else if(sdram_rd_picture_sop) begin
        sdram_rd_picture_hold <= 1'b1;
    end
end

assign sdram_rd_picture_eop = sdram_rd_picture_hold && rsdram_burst_col_cnt == col_len_m1 && rsdram_burst_row_cnt == row_len_m1;



/*----------------------------------------------------------*/

always@(posedge sdram_clk) begin
    if(reset) begin
        arbit_req <= 1'b0;
    end
    else if(arbit_allow_pos) begin
        arbit_req <= 1'b0;
    end
    else if(!arbit_allow && sdram_rd_picture_hold && hdmi_driver_buf_req_r && !hdmi_driver_buf_done && (!Sdr_init_ref_vld && !Sdr_ref_hold) && !sdram_rd_burst_hold && !sfifo_read_hold) begin
        arbit_req <= 1'b1;
    end

    arbit_allow_r3 <= {arbit_allow_r3[1:0],arbit_allow};
end

assign arbit_allow_pos = arbit_allow & !arbit_allow_r3[0];

always@(posedge sdram_clk) begin
    arbit_end <= Sdr_rd_en_eop;
end

/*----------------------------------------------------------*/

always@(posedge sdram_clk) begin
    sdram_rd_burst_sop <= arbit_allow_pos;
end

// always@(posedge sdram_clk) begin
//     if(!sdram_rd_burst_sop && !sdram_rd_burst_hold && sdram_rd_picture_hold && hdmi_driver_buf_req_r && !hdmi_driver_buf_done && !Sdr_init_ref_vld) begin
//         sdram_rd_burst_sop <= 1'b1;
//     end
//     else begin
//         sdram_rd_burst_sop <= 1'b0;
//     end
// end

always@(posedge sdram_clk) begin
    if(reset) begin
        sdram_rd_burst_hold <= 1'b0;
    end
    else if(sdram_rd_burst_eop) begin
        sdram_rd_burst_hold <= 1'b0;
    end
    else if(sdram_rd_burst_sop) begin
        sdram_rd_burst_hold <= 1'b1;
    end

    sdram_rd_burst_eop_r3 <= {sdram_rd_burst_eop_r3[1:0],sdram_rd_burst_eop};
end

assign sdram_rd_burst_eop = sdram_rd_burst_hold && rsdram_burst_col_cnt == col_len_m1;

always@(posedge sdram_clk) begin
    if(reset) begin
        rsdram_burst_col_cnt <= 13'd0;
    end
    else if(rsdram_burst_col_cnt == col_len_m1) begin
        rsdram_burst_col_cnt <= 13'd0;
    end
    else if(sdram_rd_burst_hold) begin
        rsdram_burst_col_cnt <= rsdram_burst_col_cnt + 1'b1;
    end
end

always@(posedge sdram_clk) begin
    if(reset) begin
        rsdram_burst_row_cnt <= 13'd0;
    end
    else if(rsdram_burst_col_cnt == col_len_m1 && rsdram_burst_row_cnt == row_len_m1) begin
        rsdram_burst_row_cnt <= 13'd0;
    end
    else if(sdram_rd_burst_hold && rsdram_burst_col_cnt == col_len_m1) begin
        rsdram_burst_row_cnt <= rsdram_burst_row_cnt + 1'b1;
    end
end

always@(posedge sdram_clk) begin
    if(reset) begin
        hdmi_driver_buf_done <= 1'b0;
    end
    else if(hdmi_vsync_neg_r8[0]) begin
        hdmi_driver_buf_done <= 1'b0;
    end
    else if(sdram_rd_picture_eop) begin
        hdmi_driver_buf_done <= 1'b1;
    end
end


always@(posedge sdram_clk) begin
    sdram_rd_en <= sdram_rd_burst_hold;

    if(reset) begin
        sdram_rd_addr <= 18'd0;
    end
    else if(hdmi_vsync_pos_r8[0]) begin
        sdram_rd_addr <= 18'd0;
    end
    else if(sdram_rd_en) begin
        sdram_rd_addr <= sdram_rd_addr + 1'b1;
    end
end

always@(posedge sdram_clk) begin
    App_rd_en       <= sdram_rd_en                          ;
    App_rd_addr     <= {sdram_bmp_index_ale,sdram_rd_addr}  ;
end

/*----------------------------------------------------------*/

always@(posedge sdram_clk) begin
    Sdr_rd_en_r1    <= Sdr_rd_en        ;
    Sdr_rd_dout_r1  <= Sdr_rd_dout      ;
    sfifo_din       <= Sdr_rd_dout_r1   ;
    sfifo_wr_en     <= Sdr_rd_en_r1     ;
end

assign Sdr_rd_en_eop = !Sdr_rd_en_r1 & sfifo_wr_en;

// synchronous_fifo#(  
//     .FIFO_WIDTH         (32                     ), 
//     .FIFO_DEPTH         (512                    ),
//     .FIFO_OREG          (0                      )
// )sfifo_rd_data_buf(
//     .clk                (sdram_clk              ),    
//     .rst                (reset                  ), 
//     .din                (sfifo_din              ),
//     .wr_en              (sfifo_wr_en            ),
//     .rd_en              (sfifo_rd_en            ),
//     .dout               (sfifo_dout             ), 
//     .full               (sfifo_full             ),
//     .empty              (sfifo_empty            ),  
//     .data_count         (sfifo_count            )  
// ); 

sfifo_rd_data_buf sfifo_rd_data_buf
(
    .rst                (reset                  ),
    .di                 (sfifo_din              ),
    .clk                (sdram_clk              ),
    .re                 (sfifo_rd_en            ),
    .we                 (sfifo_wr_en            ),
    .dout               (sfifo_dout             ),
    .empty_flag         (sfifo_empty            ),
    .aempty             (),
    .full_flag          (sfifo_full             ),
    .afull              (),
    .valid              (),
    .overflow           (),
    .underflow          (),
    .wr_success         (),
    .rdusedw            (sfifo_count            ),
    .wrusedw            (),
    .wr_rst_done        (),
    .rd_rst_done        ()
);


assign sfifo_rd_en = sfifo_read_hold && sfifo_read_cnt[1:0] != 2'd3;

always@(posedge sdram_clk) begin
    sfifo_read_sop <= sfifo_count >= 9'd3 && !sfifo_read_hold && !sfifo_read_sop;

    if(reset) begin
        sfifo_read_hold <= 1'b0;
    end
    else if(sfifo_read_eop) begin
        sfifo_read_hold <= 1'b0;
    end
    else if(sfifo_read_sop) begin
        sfifo_read_hold <= 1'b1;
    end

    sfifo_read_hold_r <= sfifo_read_hold;
    sfifo_read_hold_rr <= sfifo_read_hold_r;
end

always@(posedge sdram_clk) begin
    if(reset) begin
        sfifo_read_cnt  <= 13'd0;
        cnt_before_last <= 13'd0;
        read_at_last    <= 1'b0;
    end
    else begin
        cnt_before_last <= sdram_bmp_width_ale - 13'd2;
        read_at_last    <= sfifo_read_hold && (sfifo_read_cnt == cnt_before_last);
        if(sfifo_read_eop)
            sfifo_read_cnt <= 13'd0;
        else if(sfifo_read_hold)
            sfifo_read_cnt <= sfifo_read_cnt + 13'd1;
    end
end

assign sfifo_read_eop = read_at_last;

always@(posedge sdram_clk) begin
    sfifo_read_eop_r12 <= {sfifo_read_eop_r12[10:0],sfifo_read_eop};
end
/*----------------------------------------------------------*/

always@(posedge sdram_clk) begin
    sfifo_out_dv    <= sfifo_read_hold_rr;
    // sfifo_out_dv    <= sfifo_read_hold_r;
    sfifo_out_data  <= sfifo_dout;
    if(sfifo_out_dv) begin
        sfifo_out_cnt <= sfifo_out_cnt + 1'b1;
    end
    else begin
        sfifo_out_cnt <= 13'd0;
    end

    sfifo_out_dv_r3 <= {sfifo_out_dv_r3[1:0],sfifo_out_dv};

    sfifo_out_data_r1 <= sfifo_out_data;
    sfifo_out_data_r2 <= sfifo_out_data_r1;
end


always@(posedge sdram_clk) begin

    sfifo_out_ale_hold <= sfifo_out_dv_r3[1];

    if(sfifo_out_dv && sfifo_out_cnt[1:0] == 2'd2) begin
        sfifo_out_rrrr_ale <= sfifo_out_data_r2 ;
        sfifo_out_gggg_ale <= sfifo_out_data_r1 ;
        sfifo_out_bbbb_ale <= sfifo_out_data    ;
        sfifo_out_ale_flag <= 1'b1;
    end
    else begin
        sfifo_out_ale_flag <= 1'b0;
    end

    if(sfifo_out_ale_hold && sfifo_out_ale_cnt == 2'd3) begin
        sfifo_out_ale_cnt <= 2'd0;
    end
    else if(sfifo_out_ale_hold) begin
        sfifo_out_ale_cnt <= sfifo_out_ale_cnt + 1'b1;
    end
    else begin
        sfifo_out_ale_cnt <= 2'd0;
    end
end


always@(posedge sdram_clk) begin

    sfifo_out_pixel_dv <= sfifo_out_ale_hold;

    if(sfifo_out_ale_hold) begin
        case(sfifo_out_ale_cnt)
            2'd0 : sfifo_out_pixel_data <= {sfifo_out_rrrr_ale[8*3+:8],sfifo_out_gggg_ale[8*3+:8],sfifo_out_bbbb_ale[8*3+:8]};
            2'd1 : sfifo_out_pixel_data <= {sfifo_out_rrrr_ale[8*2+:8],sfifo_out_gggg_ale[8*2+:8],sfifo_out_bbbb_ale[8*2+:8]};
            2'd2 : sfifo_out_pixel_data <= {sfifo_out_rrrr_ale[8*1+:8],sfifo_out_gggg_ale[8*1+:8],sfifo_out_bbbb_ale[8*1+:8]};
            2'd3 : sfifo_out_pixel_data <= {sfifo_out_rrrr_ale[8*0+:8],sfifo_out_gggg_ale[8*0+:8],sfifo_out_bbbb_ale[8*0+:8]};
        endcase
    end
    else begin
        sfifo_out_pixel_data <= 24'd0;
    end
end

always@(posedge sdram_clk) begin
    sdram_rd_pixel_dv   <= sfifo_out_pixel_dv   ;
    sdram_rd_pixel_data <= sfifo_out_pixel_data ;
end



endmodule
