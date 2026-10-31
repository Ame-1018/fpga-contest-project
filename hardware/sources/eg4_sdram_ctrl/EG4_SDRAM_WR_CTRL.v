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
// Module Name: EG4_SDRAM_WR_CTRL
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

module EG4_SDRAM_WR_CTRL(
    input   wire                clk                         ,
    input   wire                reset                       ,

    input   wire                sd_bmp_wr_start             ,
    input   wire    [2:0]       sd_bmp_wr_index             ,
    input   wire    [12:0]      sd_bmp_wr_width             ,
    input   wire    [12:0]      sd_bmp_wr_height            ,
    input   wire                sd_bmp_wr_dv                ,
    input   wire    [23:0]      sd_bmp_wr_data              ,
    input   wire    [12:0]      sd_bmp_wr_xcnt              ,
    input   wire    [12:0]      sd_bmp_wr_ycnt              ,
    
    input   wire                sdram_clk                   ,

    input   wire                Sdr_init_done               ,
    input   wire                Sdr_init_ref_vld            ,
    input   wire                Sdr_ref_hold                ,

    output  reg                 arbit_req                   ,
    output  reg                 arbit_end                   ,
    input   wire                arbit_allow                 ,

    output  reg                 App_wr_en                   ,
    output  reg     [20:0]      App_wr_addr                 , 	
    output  reg     [3:0]       App_wr_dm                   ,
    output  reg     [31:0]      App_wr_din                  
);

reg                             sd_bmp_wr_start_r           ;

reg     [2:0]                   sd_bmp_wr_index_ale         ;
reg     [12:0]                  sd_bmp_wr_width_ale         ;
reg     [12:0]                  sd_bmp_wr_height_ale        ;
reg                             sd_bmp_wr_dv_r              ;
reg     [23:0]                  sd_bmp_wr_data_r            ;
reg     [12:0]                  sd_bmp_wr_xcnt_r            ;
reg     [12:0]                  sd_bmp_wr_ycnt_r            ;
reg     [31:0]                  pixel_rrrr                  ;
reg     [31:0]                  pixel_gggg                  ;
reg     [31:0]                  pixel_bbbb                  ;
reg     [31:0]                  pixel_rrrr_ale              ;
reg     [31:0]                  pixel_gggg_ale              ;
reg     [31:0]                  pixel_bbbb_ale              ;

reg                             pixel_wr_extend_start       ;
reg                             pixel_wr_extend_hold        ;
reg     [2:0]                   pixel_wr_extend_cnt         ;

/*----------------------------------------------------------*/
reg                             asfifo_wr_hold              ;

reg                             asfifo_we_pre               ;
reg     [31:0]                  asfifo_di_pre               ;

reg                             asfifo_we                   ;
reg     [31:0]                  asfifo_di                   ;
wire                            asfifo_re                   ;
wire                            asfifo_valid                ;
wire    [31:0]                  asfifo_dout                 ;
wire                            asfifo_empty_flag           ;
wire                            asfifo_full_flag            ;
wire                            asfifo_overflow             ;
wire                            asfifo_underflow            ;
wire    [9:0]                   asfifo_rdusedw              ;
wire    [9:0]                   asfifo_wrusedw              ;
/*----------------------------------------------------------*/
reg                             change_wr_start             ;//clk change
reg                             change_wr_start_hold        ;//clk change
reg     [3:0]                   change_wr_start_hold_cnt    ;//clk change

reg     [2:0]                   change_wr_start_hold_r3     ;//clk change
reg                             change_wr_start_hold_pos    ;//clk change


reg                             sdram_wr_start              ;
reg                             sdram_wr_hold               ;
reg                             sdram_wr_end                ;

reg                             sdram_init_done             ;

reg     [12:0]                  wsdram_burst_row_length     ;
reg     [12:0]                  wsdram_burst_row_cnt        ;
reg     [12:0]                  wsdram_burst_col_length     ;
reg     [12:0]                  col_len_m1                  ;
reg     [12:0]                  row_len_m1                  ;
reg     [12:0]                  wsdram_burst_col_cnt        ;

reg                             asfifo_rd_nempty            ;
reg                             asfifo_rd_nempty_r          ;
wire                            asfifo_rd_nempty_pos        ;
reg     [3:0]                   asfifo_rd_nempty_pos_r4     ;

reg     [2:0]                   arbit_allow_r3              ;
wire                            arbit_allow_pos             ;

reg                             wsdram_sop                  ;
reg                             wsdram_hold                 ;
wire                            wsdram_eop                  ;

reg                             wsdram_hold_r               ;

reg                             wsdram_en                   ;
reg     [17:0]                  wsdram_addr                 ;
reg     [3:0]                   wsdram_dm                   ;
reg     [31:0]                  wsdram_data                 ;



/*----------------------------------------------------------*/

always@(posedge clk) begin
    sd_bmp_wr_start_r <= sd_bmp_wr_start;
end

always@(posedge clk) begin
    if(reset) begin
        sd_bmp_wr_index_ale     <= 2'd0;
        sd_bmp_wr_width_ale     <= 13'd0;
        sd_bmp_wr_height_ale    <= 13'd0;
    end
    else if(sd_bmp_wr_start_r) begin
        sd_bmp_wr_index_ale     <= sd_bmp_wr_index;
        sd_bmp_wr_width_ale     <= sd_bmp_wr_width;
        sd_bmp_wr_height_ale    <= sd_bmp_wr_height;
    end
end

always@(posedge clk) begin
    sd_bmp_wr_dv_r      <= sd_bmp_wr_dv     ;
    sd_bmp_wr_data_r    <= sd_bmp_wr_data   ;
    sd_bmp_wr_xcnt_r    <= sd_bmp_wr_xcnt   ;
    sd_bmp_wr_ycnt_r    <= sd_bmp_wr_ycnt   ;
end

always@(posedge clk) begin
    sd_bmp_wr_start_r <= sd_bmp_wr_start;
    if(sd_bmp_wr_dv_r) begin
        case(sd_bmp_wr_xcnt_r[1:0]) 
            2'd0 : begin 
                pixel_rrrr[3*8+:8] <= sd_bmp_wr_data_r[2*8+:8];
                pixel_gggg[3*8+:8] <= sd_bmp_wr_data_r[1*8+:8];
                pixel_bbbb[3*8+:8] <= sd_bmp_wr_data_r[0*8+:8];
            end
            2'd1 : begin 
                pixel_rrrr[2*8+:8] <= sd_bmp_wr_data_r[2*8+:8];
                pixel_gggg[2*8+:8] <= sd_bmp_wr_data_r[1*8+:8];
                pixel_bbbb[2*8+:8] <= sd_bmp_wr_data_r[0*8+:8];
            end
            2'd2 : begin 
                pixel_rrrr[1*8+:8] <= sd_bmp_wr_data_r[2*8+:8];
                pixel_gggg[1*8+:8] <= sd_bmp_wr_data_r[1*8+:8];
                pixel_bbbb[1*8+:8] <= sd_bmp_wr_data_r[0*8+:8];
            end
            2'd3 : begin 
                pixel_rrrr[0*8+:8] <= sd_bmp_wr_data_r[2*8+:8];
                pixel_gggg[0*8+:8] <= sd_bmp_wr_data_r[1*8+:8];
                pixel_bbbb[0*8+:8] <= sd_bmp_wr_data_r[0*8+:8];
            end
        endcase
    end

    if(sd_bmp_wr_dv_r && sd_bmp_wr_xcnt_r[1:0] == 2'd3) begin
        pixel_rrrr_ale <= {pixel_rrrr[31:8],sd_bmp_wr_data_r[2*8+:8]};
        pixel_gggg_ale <= {pixel_gggg[31:8],sd_bmp_wr_data_r[1*8+:8]};
        pixel_bbbb_ale <= {pixel_bbbb[31:8],sd_bmp_wr_data_r[0*8+:8]};
    end
end

always@(posedge clk) begin
    if(sd_bmp_wr_start_r) begin
        asfifo_wr_hold <= 1'b0;
    end
    else if(sd_bmp_wr_dv_r && sd_bmp_wr_xcnt_r == 13'd3) begin
        asfifo_wr_hold <= 1'b1;
    end
end

always@(posedge clk) begin
    pixel_wr_extend_start <= sd_bmp_wr_dv_r && sd_bmp_wr_xcnt_r == sd_bmp_wr_width_ale - 1'b1 && sd_bmp_wr_ycnt_r == sd_bmp_wr_height_ale - 1'b1;

    if(reset) begin
        pixel_wr_extend_hold <= 1'b0;
    end
    else if(pixel_wr_extend_cnt == 3'd3) begin
        pixel_wr_extend_hold <= 1'b0;
    end
    else if(pixel_wr_extend_start) begin
        pixel_wr_extend_hold <= 1'b1;
    end

    if(pixel_wr_extend_hold) begin
        pixel_wr_extend_cnt <= pixel_wr_extend_cnt + 1'b1;
    end
    else begin
        pixel_wr_extend_cnt <= 3'd0;
    end   
end


always@(posedge clk) begin
    if(sd_bmp_wr_dv_r && asfifo_wr_hold) begin
        case(sd_bmp_wr_xcnt_r[1:0])
            2'd0 : begin 
                asfifo_we_pre <= 1'b1;
                asfifo_di_pre <= pixel_rrrr_ale;
            end
            2'd1 : begin 
                asfifo_we_pre <= 1'b1;
                asfifo_di_pre <= pixel_gggg_ale;
            end
            2'd2 : begin 
                asfifo_we_pre <= 1'b1;
                asfifo_di_pre <= pixel_bbbb_ale;
            end
            2'd3 : begin 
                asfifo_we_pre <= 1'b0;
            end
        endcase
    end
    else if(pixel_wr_extend_hold) begin
        case(pixel_wr_extend_cnt[1:0])
            2'd0 : begin 
                asfifo_we_pre <= 1'b1;
                asfifo_di_pre <= pixel_rrrr_ale;
            end
            2'd1 : begin 
                asfifo_we_pre <= 1'b1;
                asfifo_di_pre <= pixel_gggg_ale;
            end
            2'd2 : begin 
                asfifo_we_pre <= 1'b1;
                asfifo_di_pre <= pixel_bbbb_ale;
            end
            2'd3 : begin 
                asfifo_we_pre <= 1'b0;
            end
        endcase
    end
    else begin
        asfifo_we_pre <= 1'b0;
    end
end

always@(posedge clk) begin
    asfifo_we <= asfifo_we_pre;
    asfifo_di <= asfifo_di_pre;
end


asfifo_sdram_wr asfifo_sdram_wr
(
    .rst                        (reset                      ),
    .di                         (asfifo_di                  ),
    .clkr                       (sdram_clk                  ),
    .re                         (asfifo_re                  ),
    .clkw                       (clk                        ),
    .we                         (asfifo_we                  ),
    .dout                       (asfifo_dout                ),
    .empty_flag                 (asfifo_empty_flag          ),
    .aempty                     (),
    .full_flag                  (asfifo_full_flag           ),
    .afull                      (),
    .valid                      (asfifo_valid               ),
    .overflow                   (asfifo_overflow            ),
    .underflow                  (asfifo_underflow           ),
    .wr_success                 (),
    .rdusedw                    (asfifo_rdusedw             ),
    .wrusedw                    (asfifo_wrusedw             ),
    .wr_rst_done                (),
    .rd_rst_done                ()
);

assign asfifo_re = wsdram_hold;

/*----------------------------------------------------------*/

always@(posedge clk) begin
    change_wr_start <= sd_bmp_wr_start_r;

    if(reset) begin
        change_wr_start_hold <= 1'b0;
    end
    else if(change_wr_start_hold && change_wr_start_hold_cnt == 4'd15) begin
        change_wr_start_hold <= 1'b0;
    end
    else if(change_wr_start) begin
        change_wr_start_hold <= 1'b1;
    end
end

always@(posedge clk) begin
    if(change_wr_start_hold) begin
        change_wr_start_hold_cnt <= change_wr_start_hold_cnt + 1'b1;
    end
    else begin
        change_wr_start_hold_cnt <= 4'd0;
    end
end

always@(posedge sdram_clk) begin
    change_wr_start_hold_r3 <= {change_wr_start_hold_r3[1:0],change_wr_start_hold};
    change_wr_start_hold_pos <= change_wr_start_hold_r3[1] & !change_wr_start_hold_r3[2];
end
    
/*----------------------------------------------------------*/

always@(posedge sdram_clk) begin
    sdram_wr_start <= change_wr_start_hold_pos;

    if(reset) begin
        sdram_wr_hold <= 1'b0;
    end
    else if(sdram_wr_end) begin
        sdram_wr_hold <= 1'b0;
    end
    else if(sdram_wr_start) begin
        sdram_wr_hold <= 1'b1;
    end

    sdram_wr_end <= wsdram_hold && wsdram_burst_col_cnt == col_len_m1 && wsdram_burst_row_cnt == row_len_m1;
end

/*----------------------------------------------------------*/


always@(posedge sdram_clk) begin
    sdram_init_done     <= Sdr_init_done        ;
end

always@(posedge sdram_clk) begin
    if(sdram_wr_start) begin
        wsdram_burst_row_length <= sd_bmp_wr_height_ale;
        wsdram_burst_col_length <= sd_bmp_wr_width_ale[12:2] + (sd_bmp_wr_width_ale[12:2] << 1);
    end
    col_len_m1 <= wsdram_burst_col_length - 13'd1;
    row_len_m1 <= wsdram_burst_row_length - 13'd1;
end

always@(posedge sdram_clk) begin
    if(reset) begin
        asfifo_rd_nempty <= 1'b0;
    end
    else if(wsdram_eop) begin
        asfifo_rd_nempty <= 1'b0;
    end
    else if(!asfifo_rd_nempty && sdram_wr_hold && sdram_init_done && (!Sdr_init_ref_vld && !Sdr_ref_hold) && asfifo_rdusedw >= wsdram_burst_col_length) begin
        asfifo_rd_nempty <= 1'b1;
    end

    asfifo_rd_nempty_r <= asfifo_rd_nempty;
    asfifo_rd_nempty_pos_r4 <= {asfifo_rd_nempty_pos_r4[2:0],asfifo_rd_nempty_pos};
end

assign asfifo_rd_nempty_pos = asfifo_rd_nempty & !asfifo_rd_nempty_r;

/*----------------------------------------------------------*/

always@(posedge sdram_clk) begin
    if(reset) begin
        arbit_req <= 1'b0;
    end
    else if(arbit_allow_pos) begin
        arbit_req <= 1'b0;
    end
    else if(asfifo_rd_nempty_pos) begin
        arbit_req <= 1'b1;
    end

    arbit_allow_r3 <= {arbit_allow_r3[1:0],arbit_allow};
end

assign arbit_allow_pos = arbit_allow & !arbit_allow_r3[0];

always@(posedge sdram_clk) begin
    arbit_end <= wsdram_eop;
end

/*----------------------------------------------------------*/

always@(posedge sdram_clk) begin
    wsdram_sop <= arbit_allow_pos;

    if(reset) begin
        wsdram_hold <= 1'b0;
    end
    else if(wsdram_eop) begin
        wsdram_hold <= 1'b0;
    end
    else if(wsdram_sop) begin
        wsdram_hold <= 1'b1;
    end
end

assign wsdram_eop = wsdram_hold && wsdram_burst_col_cnt == col_len_m1;

always@(posedge sdram_clk) begin
    if(reset) begin
        wsdram_burst_col_cnt <= 13'd0;
    end
    else if(wsdram_hold && wsdram_burst_col_cnt == col_len_m1) begin
        wsdram_burst_col_cnt <= 13'd0;
    end
    else if(wsdram_hold) begin
        wsdram_burst_col_cnt <= wsdram_burst_col_cnt + 1'b1;
    end

    if(reset) begin
        wsdram_burst_row_cnt <= 13'd0;
    end
    else if(wsdram_hold && wsdram_burst_col_cnt == col_len_m1 && wsdram_burst_row_cnt == row_len_m1) begin
        wsdram_burst_row_cnt <= 13'd0;
    end
    else if(wsdram_hold && wsdram_burst_col_cnt == col_len_m1) begin
        wsdram_burst_row_cnt <= wsdram_burst_row_cnt + 1'b1;
    end

    wsdram_hold_r <= wsdram_hold;
end


always@(posedge sdram_clk) begin
    if(wsdram_hold_r) begin
        wsdram_en <= 1'b1;
    end
    else begin
        wsdram_en <= 1'b0;
    end

    if(sdram_wr_start) begin
        wsdram_addr <= 18'd0;
    end
    else if(wsdram_en) begin
        wsdram_addr <= wsdram_addr + 1'b1;
    end

    wsdram_dm <= 4'd0;

    wsdram_data <= wsdram_hold_r ? asfifo_dout : 32'd0;
end


always@(posedge sdram_clk) begin
    App_wr_en   <= wsdram_en    ;
    App_wr_addr <= wsdram_en ? {sd_bmp_wr_index_ale,wsdram_addr} : 21'd0;
    App_wr_dm   <= wsdram_dm    ;
    App_wr_din  <= wsdram_data  ;  
end


// wire                            asfifo_valid                ;
// wire    [31:0]                  asfifo_dout                 ;






endmodule
