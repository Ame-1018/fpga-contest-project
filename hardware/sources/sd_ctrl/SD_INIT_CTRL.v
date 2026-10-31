`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Create Date: 2026/10/08 09:21:17
// Module Name: SD_INIT_CTRL
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


module SD_INIT_CTRL #(
    parameter                   CLK_FREQ                    = 50_000_000
)(
    input   wire                clk                         ,
    input   wire                reset                       ,

    input   wire                sd_sdio_clk                 ,

    input   wire                sd_init_req                 ,
    output  reg                 sd_init_done                ,
    output  reg                 sd_init_clk_done            ,

    output  reg                 sd_init_tx_nrp_req          ,//no responding
    output  reg                 sd_init_tx_rp_req           ,//   responding
    output  reg     [5:0]       sd_init_tx_nub              ,
    output  reg     [31:0]      sd_init_tx_data             ,
    input   wire                sd_init_tx_ack              ,
    input   wire                sd_init_tx_end              ,

    input   wire                sd_init_rp_ack              ,
    input   wire    [2:0]       sd_init_rp_type             ,
    input   wire    [31:0]      sd_init_rp_data_Rx          ,
    input   wire    [119:0]     sd_init_rp_data_R2          ,
    input   wire                sd_init_rp_err              ,
    input   wire                sd_init_rp_timeout          
);
`ifndef SIM_MODE
localparam                      SD_INIT_CNT_END             = 100_000_000 / (1_000_000_000 / CLK_FREQ);
`else 
localparam                      SD_INIT_CNT_END             = 500;
`endif 

localparam                      SD_INIT_DELAY_CNT           = 64 - 1;

parameter                       INIT_IDLE                   = 4'd0  ,
                                INIT_CMD0                   = 4'd1  ,
                                INIT_CMD8                   = 4'd2  ,
                                INIT_CMD55_A41              = 4'd3  ,
                                INIT_ACMD41                 = 4'd4  ,
                                INIT_CMD2                   = 4'd5  ,
                                INIT_CMD3                   = 4'd6  ,
                                INIT_CMD7                   = 4'd7  ,
                                INIT_CMD55_A6               = 4'd8  ,
                                INIT_ACMD6                  = 4'd9  ,
                                INIT_CMD16                  = 4'd10 ,
                                INIT_DONE                   = 4'd11 ,
                                INIT_FAIL                   = 4'd12 ;

reg     [31:0]                  sd_init_start_cnt           ;
reg                             sd_init_start_flag          ;

reg     [3:0]                   sd_init_state               ;
reg     [3:0]                   sd_init_state_r             ;
reg     [3:0]                   sd_init_state_rr            ;

reg                             sd_init_state_change_flag   ;

reg                             sd_sdio_clk_r               ;
reg                             sd_sdio_clk_rr              ;
wire                            sd_sdio_clk_pos             ;

reg                             sd_init_delay_start         ;
reg     [7:0]                   sd_init_delay_cnt           ;
reg                             sd_init_delay_flag          ;

reg                             sd_init_acmd41_loop_start   ;
reg     [7:0]                   sd_init_acmd41_loop_cnt     ;
reg                             sd_init_acmd41_loop_flag    ;

reg                             sd_init_fail_flag           ;

reg     [119:0]                 sd_reg_CID                  ;
reg     [15:0]                  sd_reg_RCA                  ;
reg     [31:0]                  sd_reg_OCR                  ;

reg                             sd_ind_done_hold            ;

always@(posedge clk) begin
    if(reset) begin
        sd_init_start_cnt <= 32'd0;
    end
    else if(sd_init_req) begin
        sd_init_start_cnt <= 32'd0;
    end
    else if(sd_init_start_cnt <= SD_INIT_CNT_END - 1'b1) begin
        sd_init_start_cnt <= sd_init_start_cnt + 1'b1;
    end

    sd_init_start_flag <= sd_init_start_cnt == SD_INIT_CNT_END - 1'b1 ? 1'b1 : 1'b0;
end

always@(posedge clk) begin
    sd_sdio_clk_r <= sd_sdio_clk;
    sd_sdio_clk_rr <= sd_sdio_clk_r;
end

assign sd_sdio_clk_pos = sd_sdio_clk_r & !sd_sdio_clk_rr;

always@(posedge clk) begin
    if(reset) begin
        sd_init_delay_cnt <= 8'd0;
    end
    else if(sd_init_delay_start) begin
        sd_init_delay_cnt <= 8'd0;
    end
    else if(sd_sdio_clk_pos && sd_init_delay_cnt <= SD_INIT_DELAY_CNT) begin
        sd_init_delay_cnt <= sd_init_delay_cnt + 1'b1;
    end

    sd_init_delay_flag <= sd_init_delay_cnt == SD_INIT_DELAY_CNT && sd_sdio_clk_pos ? 1'b1 : 1'b0;
end

always@(posedge clk) begin
    if(reset) begin
        sd_init_acmd41_loop_cnt <= 8'd0;
    end
    else if(sd_init_acmd41_loop_start) begin
        sd_init_acmd41_loop_cnt <= 8'd0;
    end
    else if(sd_sdio_clk_pos && sd_init_acmd41_loop_cnt <= SD_INIT_DELAY_CNT) begin
        sd_init_acmd41_loop_cnt <= sd_init_acmd41_loop_cnt + 1'b1;
    end

    sd_init_acmd41_loop_flag <= sd_init_acmd41_loop_cnt == SD_INIT_DELAY_CNT && sd_sdio_clk_pos ? 1'b1 : 1'b0;
end

always@(posedge clk) begin
    if(reset) begin
        sd_init_state <= INIT_IDLE;
    end
    else if(sd_init_fail_flag) begin
        sd_init_state <= INIT_FAIL;
    end
    else begin
        case(sd_init_state)
            INIT_IDLE       :  begin if(sd_init_start_flag) begin sd_init_state <= INIT_CMD0        ;end end
            INIT_CMD0       :  begin if(sd_init_delay_flag) begin sd_init_state <= INIT_CMD8        ;end end
            INIT_CMD8       :  begin if(sd_init_delay_flag) begin sd_init_state <= INIT_CMD55_A41   ;end end
            INIT_CMD55_A41  :  begin if(sd_init_delay_flag) begin sd_init_state <= INIT_ACMD41      ;end end
            INIT_ACMD41     :  begin 
                if(sd_init_delay_flag) begin 
                    sd_init_state <= INIT_CMD2;
                end 
                else if(sd_init_acmd41_loop_flag) begin
                    sd_init_state <= INIT_CMD55_A41;
                end                
            end
            INIT_CMD2       :  begin if(sd_init_delay_flag) begin sd_init_state <= INIT_CMD3        ;end end
            INIT_CMD3       :  begin if(sd_init_delay_flag) begin sd_init_state <= INIT_CMD7        ;end end
            INIT_CMD7       :  begin if(sd_init_delay_flag) begin sd_init_state <= INIT_CMD55_A6    ;end end
            INIT_CMD55_A6   :  begin if(sd_init_delay_flag) begin sd_init_state <= INIT_ACMD6       ;end end
            INIT_ACMD6      :  begin if(sd_init_delay_flag) begin sd_init_state <= INIT_DONE        ;end end
            INIT_DONE       :  begin if(sd_init_req) begin        sd_init_state <= INIT_IDLE        ;end end
            INIT_FAIL       :  begin if(sd_init_req) begin        sd_init_state <= INIT_IDLE        ;end end
            default         :  begin                              sd_init_state <= INIT_IDLE        ;end
        endcase
    end

    sd_init_state_r <= sd_init_state;
    sd_init_state_rr <= sd_init_state_r;

    sd_init_state_change_flag <= sd_init_state_rr != sd_init_state_r;
end

always@(posedge clk) begin
    if(reset) begin
        sd_init_tx_nub      <= 6'd0;
        sd_init_tx_data     <= 32'd0;
    end
    else if(sd_init_state_change_flag) begin
        case(sd_init_state_rr)   
            // INIT_CMD0       : begin sd_init_tx_nub <= 6'd8  ;sd_init_tx_data <= 32'h7C5A1F01        ;end
            INIT_CMD0       : begin sd_init_tx_nub <= 6'd0  ;sd_init_tx_data <= 32'h0               ;end
            INIT_CMD8       : begin sd_init_tx_nub <= 6'd8  ;sd_init_tx_data <= 32'h000001AA        ;end
            INIT_CMD55_A41  : begin sd_init_tx_nub <= 6'd55 ;sd_init_tx_data <= {sd_reg_RCA,16'h0}  ;end
            INIT_ACMD41     : begin sd_init_tx_nub <= 6'd41 ;sd_init_tx_data <= 32'h40100000        ;end
            INIT_CMD2       : begin sd_init_tx_nub <= 6'd2  ;sd_init_tx_data <= 32'h00000000        ;end
            INIT_CMD3       : begin sd_init_tx_nub <= 6'd3  ;sd_init_tx_data <= 32'h00000000        ;end
            INIT_CMD7       : begin sd_init_tx_nub <= 6'd7  ;sd_init_tx_data <= {sd_reg_RCA,16'h0}  ;end
            INIT_CMD55_A6   : begin sd_init_tx_nub <= 6'd55 ;sd_init_tx_data <= {sd_reg_RCA,16'h0}  ;end
            INIT_ACMD6      : begin sd_init_tx_nub <= 6'd6  ;sd_init_tx_data <= 32'h00000002        ;end
            default         : begin sd_init_tx_nub <= 6'd0  ;sd_init_tx_data <= 32'h0               ;end
        endcase
    end
end

always@(posedge clk) begin
    if(reset) begin
        sd_reg_CID <= 120'h0;
        sd_reg_RCA <= 16'h0;
        sd_reg_OCR <= 32'h0;
    end
    else if(sd_init_req) begin
        sd_reg_CID <= 120'h0;
        sd_reg_RCA <= 16'h0;
        sd_reg_OCR <= 32'h0;
    end
    else if(sd_init_state_rr == INIT_CMD2 && sd_init_rp_ack) begin
        sd_reg_CID <= sd_init_rp_data_R2[119:0];
    end
    else if(sd_init_state_rr == INIT_CMD3 && sd_init_rp_ack) begin
        sd_reg_RCA <= sd_init_rp_data_Rx[31:16];
    end
    else if(sd_init_state_rr == INIT_ACMD41 && sd_init_rp_ack) begin
        sd_reg_OCR <= sd_init_rp_data_Rx[31:0];
    end
end

always@(posedge clk) begin
    if(reset) begin
        sd_init_tx_rp_req <= 1'b0;
    end
    else if(sd_init_req) begin
        sd_init_tx_rp_req <= 1'b0;
    end
    else if(sd_init_state_change_flag && (sd_init_state_rr != INIT_IDLE && sd_init_state_rr != INIT_CMD0 && sd_init_state_rr != INIT_FAIL && sd_init_state_rr != INIT_DONE)) begin
        sd_init_tx_rp_req <= 1'b1;
    end
    else if(sd_init_tx_ack) begin
        sd_init_tx_rp_req <= 1'b0;
    end

    if(reset) begin
        sd_init_tx_nrp_req <= 1'b0;
    end
    else if(sd_init_req) begin
        sd_init_tx_nrp_req <= 1'b0;
    end
    else if(sd_init_state_change_flag && sd_init_state_rr == INIT_CMD0) begin
        sd_init_tx_nrp_req <= 1'b1;
    end
    else if(sd_init_tx_ack) begin
        sd_init_tx_nrp_req <= 1'b0;
    end
end

always@(posedge clk) begin
    if(sd_init_tx_end && sd_init_state_rr == INIT_CMD0) begin
        sd_init_delay_start <= 1'b1;
    end
    else if(sd_init_rp_ack) begin
        case(sd_init_state_rr)   
            INIT_CMD8       : begin sd_init_delay_start <= 1'b1                             ;end
            INIT_CMD55_A41  : begin sd_init_delay_start <= 1'b1                             ;end
            INIT_ACMD41     : begin 
                if(sd_init_rp_data_Rx[31] == 1'b1 && sd_init_rp_data_Rx[30] == 1'b1) begin
                    sd_init_delay_start <= 1'b1;
                end
            end
            INIT_CMD2       : begin sd_init_delay_start <= 1'b1                             ;end
            INIT_CMD3       : begin sd_init_delay_start <= 1'b1                             ;end
            INIT_CMD7       : begin sd_init_delay_start <= 1'b1                             ;end
            INIT_CMD55_A6   : begin sd_init_delay_start <= 1'b1                             ;end
            INIT_ACMD6      : begin sd_init_delay_start <= 1'b1                             ;end
            default         : begin sd_init_delay_start <= 1'b0                             ;end
        endcase
    end
    else begin
        sd_init_delay_start <= 1'b0;
    end
end

always@(posedge clk) begin
    if(sd_init_rp_ack && sd_init_state_rr == INIT_ACMD41 && sd_init_rp_data_Rx[31] != 1'b1) begin
        sd_init_acmd41_loop_start <= 1'b1;
    end
    else begin
        sd_init_acmd41_loop_start <= 1'b0;
    end
end

always@(posedge clk) begin
    if(sd_init_rp_timeout) begin
        sd_init_fail_flag <= 1'b1;
    end
    else if(sd_init_rp_ack) begin
        case(sd_init_state_rr)   
            INIT_CMD8       : begin sd_init_fail_flag <= sd_init_rp_err || sd_init_rp_data_Rx[11:0] != 12'h1AA                              ;end
            INIT_CMD55_A41  : begin sd_init_fail_flag <= sd_init_rp_err || sd_init_rp_data_Rx[31:19] != 'd0 || sd_init_rp_data_Rx[5] != 1'b1;end
            INIT_ACMD41     : begin sd_init_fail_flag <= sd_init_rp_data_Rx[31] == 1'b1 && sd_init_rp_data_Rx[30] == 1'b0 ? 1'b1 : 1'b0     ;end
            INIT_CMD2       : begin sd_init_fail_flag <= sd_init_rp_err                                                                     ;end
            INIT_CMD3       : begin sd_init_fail_flag <= sd_init_rp_err || sd_init_rp_data_Rx[31:16] == 16'd0                               ;end
            INIT_CMD7       : begin sd_init_fail_flag <= sd_init_rp_err || sd_init_rp_data_Rx[31:19] != 'd0 || sd_init_rp_data_Rx[5] != 1'b0;end
            INIT_CMD55_A6   : begin sd_init_fail_flag <= sd_init_rp_err || sd_init_rp_data_Rx[31:19] != 'd0 || sd_init_rp_data_Rx[5] != 1'b1;end
            INIT_ACMD6      : begin sd_init_fail_flag <= sd_init_rp_err || sd_init_rp_data_Rx[31:19] != 'd0 || sd_init_rp_data_Rx[5] != 1'b1;end
            default         : begin sd_init_fail_flag <= 1'b0                                                                               ;end
        endcase
    end
    else begin
        sd_init_fail_flag <= 1'b0;
    end
end

always@(posedge clk) begin
    if(reset) begin
        sd_init_clk_done <= 1'b0;
    end
    else if(sd_init_req) begin
        sd_init_clk_done <= 1'b0;
    end
    // else if(sd_init_delay_flag && sd_init_state_rr == INIT_CMD7) begin
    else if(sd_init_delay_flag && sd_init_state_rr == INIT_CMD3) begin
        sd_init_clk_done <= 1'b1;
    end
end


always@(posedge clk) begin
    sd_ind_done_hold    <= sd_init_state_rr == INIT_DONE ? 1'b1 : 1'b0;
end

always@(posedge clk) begin
    sd_init_done        <= sd_ind_done_hold;
end



endmodule
