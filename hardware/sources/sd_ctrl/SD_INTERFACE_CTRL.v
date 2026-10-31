`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Module Name: SD_INTERFACE_CTRL
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


module SD_INTERFACE_CTRL #(
    parameter                   CLK_FREQ                    = 50_000_000
)(
    input   wire                clk                         ,
    input   wire                reset                       ,

    input   wire                sd_sdio_clk                 ,

    input   wire                sd_cmd_tx_nrp_req           ,//no responding
    input   wire                sd_cmd_tx_rp_req            ,//   responding
    input   wire    [5:0]       sd_cmd_tx_nub               ,
    input   wire    [31:0]      sd_cmd_tx_data              ,
    output  reg                 sd_cmd_tx_ack               ,
    output  reg                 sd_cmd_tx_end               ,

    output  reg                 sd_cmd_rp_ack               ,
    output  reg     [2:0]       sd_cmd_rp_type              ,
    output  reg     [31:0]      sd_cmd_rp_data_Rx           ,
    output  reg     [119:0]     sd_cmd_rp_data_R2           ,
    output  reg                 sd_cmd_rp_err               ,
    output  reg                 sd_cmd_rp_timeout           ,

    output  reg                 sd_write_data_req           ,
    input   wire                sd_write_dv                 ,
    input   wire    [7:0]       sd_write_data               ,
    output  reg                 sd_write_end                ,

    output  reg                 sd_read_start               ,
    output  reg                 sd_read_dv                  ,
    output  reg     [7:0]       sd_read_data                ,
    output  reg                 sd_read_end                 ,
    output  reg     [8:0]       sd_read_cnt                 ,

    output  reg     [3:0]       sd_read_crc_err             ,

    output  wire                SD_SDIO_CLK                 ,
    inout   wire                SD_SDIO_CMD                 ,
    inout   wire    [3:0]       SD_SDIO_DATA                
);

reg                             sd_sdio_clk_r               ;
reg                             sd_sdio_clk_rr              ;
wire                            sd_sdio_clk_pos             ;
wire                            sd_sdio_clk_neg             ;

parameter                       STA_CMD_IDLE                = 3'd0  ,
                                STA_CMD_PRE_DLY             = 3'd1  ,
                                STA_CMD_SEND                = 3'd2  ,
                                STA_CMD_WAIT                = 3'd3  ,
                                STA_CMD_RP_RCV              = 3'd4  ,
                                STA_CMD_DONE                = 3'd5  ;

reg     [2:0]                   cmd_state                   ;

reg                             cmd_rp_nrp_sel              ;

reg                             cmd_pre_hold                ;
reg     [2:0]                   cmd_pre_dly_cnt             ;

reg                             cmd_send_hold               ;
reg                             cmd_send_flag               ;
reg     [5:0]                   cmd_send_cnt                ;
reg     [39:0]                  cmd_send_shift_data         ;
reg     [6:0]                   cmd_send_crc                ;

reg                             sd_sdio_cmd_send_data       ;


reg     [2:0]                   cmd_rp_type                 ;
reg     [7:0]                   cmd_rp_bit_nub              ;

reg                             cmd_rp_rcv_flag             ;
reg                             cmd_rp_rcv_data             ;
wire                            cmd_rp_rcv_start            ;
reg                             cmd_rp_rcv_hold             ;
reg                             cmd_rp_rcv_end              ;
reg     [7:0]                   cmd_rp_rcv_cnt              ;
reg     [135:0]                 cmd_rp_rcv_shift            ;
reg     [6:0]                   cmd_rp_rcv_crc7             ;
reg                             cmd_rp_rcv_crc7_err_hold    ;

parameter                       R1B_BUSY_END_NUB            = 16;

reg     [7:0]                   cmd_rp_rcv_R1b_busy_cnt     ;

reg     [27:0]                  cmd_rp_time_cnt             ;

/*----------------------------------------------------------*/

parameter                       STA_READ_IDLE               = 3'd0  ,
                                STA_READ_WAIT               = 3'd1  ,
                                STA_READ_RCV                = 3'd2  ,
                                STA_READ_DONE               = 3'd3  ;

parameter                       READ_CNT_END_NUB            = 1024 + 16 - 1;

reg     [2:0]                   read_state                  ;

wire                            read_start                  ;
reg                             read_hold                   ;
reg                             read_flag                   ;
reg     [3:0]                   read_data                   ;
reg     [10:0]                  read_cnt                    ;
reg                             read_end                    ;
reg                             read_shift_dv               ;
reg     [7:0]                   read_shift_data             ;

reg     [15:0]                  read_crc16      [3:0]       ;
reg     [3:0]                   read_crc16_err              ;



function [6:0] CalcCrc7;
    input [6:0] crc;
    input       inbit;
    reg         xorb;
    begin
        xorb     = crc[6] ^ inbit;
        CalcCrc7 = (crc << 1) ^ {3'b0, xorb, 2'b0, xorb};
    end
endfunction

function [15:0] CalcCrc16;
    input [15:0] crc;
    input        inbit;
    reg          xorb;
    begin
        xorb      = crc[15] ^ inbit;
        CalcCrc16 = (crc << 1) ^ {3'b0, xorb, 6'b0, xorb, 4'b0, xorb};
    end
endfunction

always@(posedge clk) begin
    sd_sdio_clk_r <= sd_sdio_clk;
    sd_sdio_clk_rr <= sd_sdio_clk_r;
end

assign sd_sdio_clk_pos = sd_sdio_clk_r & !sd_sdio_clk_rr;
assign sd_sdio_clk_neg = !sd_sdio_clk_r & sd_sdio_clk_rr;


always@(posedge clk) begin
    if(cmd_state == STA_CMD_IDLE && sd_cmd_tx_rp_req) begin
        cmd_rp_nrp_sel <= 1'b1;
    end
    else if(cmd_state == STA_CMD_IDLE && sd_cmd_tx_nrp_req) begin
        cmd_rp_nrp_sel <= 1'b0;
    end
end

always@(posedge clk) begin
    if(reset) begin
        cmd_state <= STA_CMD_IDLE;
    end
    else begin
        case(cmd_state)
            STA_CMD_IDLE    : begin if(sd_cmd_tx_rp_req | sd_cmd_tx_nrp_req)        begin cmd_state <= STA_CMD_PRE_DLY  ;end end
            STA_CMD_PRE_DLY : begin if(sd_sdio_clk_neg && cmd_pre_dly_cnt == 3'd2)  begin cmd_state <= STA_CMD_SEND     ;end end
            STA_CMD_SEND    : begin 
                if(cmd_send_flag && cmd_send_cnt == 6'd48 && cmd_rp_nrp_sel == 1'b1) begin 
                    cmd_state <= STA_CMD_WAIT;
                end 
                else if(cmd_send_flag && cmd_send_cnt == 6'd48 && cmd_rp_nrp_sel == 1'b0) begin 
                    cmd_state <= STA_CMD_DONE;
                end
            end
            STA_CMD_WAIT    : begin 
                if(sd_cmd_rp_timeout) begin 
                    cmd_state <= STA_CMD_IDLE;
                end 
                else if(cmd_rp_rcv_start) begin
                    cmd_state <= STA_CMD_RP_RCV;
                end
            end
            STA_CMD_RP_RCV  : begin 
                if(sd_cmd_rp_timeout) begin
                    cmd_state <= STA_CMD_IDLE;
                end
                else if(cmd_rp_rcv_end) begin
                    cmd_state <= STA_CMD_DONE;
                end 
            end
            STA_CMD_DONE    : begin cmd_state <= STA_CMD_IDLE     ;end
            default         : begin cmd_state <= STA_CMD_IDLE     ;end
        endcase
    end
end

always@(posedge clk) begin
    if((sd_cmd_tx_rp_req | sd_cmd_tx_nrp_req) && cmd_state == STA_CMD_PRE_DLY && !sd_cmd_tx_ack) begin
        sd_cmd_tx_ack <= 1'b1;
    end
    else begin
        sd_cmd_tx_ack <= 1'b0;
    end
    
    sd_cmd_tx_end <= cmd_send_flag && cmd_send_cnt == 6'd48 ? 1'b1 : 1'b0;
end



always@(posedge clk) begin
    if(cmd_state == STA_CMD_PRE_DLY && sd_sdio_clk_neg) begin
        cmd_pre_dly_cnt <= cmd_pre_dly_cnt + 1'b1;
    end
    else if(cmd_state != STA_CMD_PRE_DLY) begin
        cmd_pre_dly_cnt <= 3'd0;
    end

    cmd_pre_hold <= cmd_state == STA_CMD_PRE_DLY ? 1'b1 : 1'b0;
end

always@(posedge clk) begin
    if(cmd_state == STA_CMD_SEND) begin
        cmd_send_flag <= sd_sdio_clk_neg;
    end
    else begin
        cmd_send_flag <= 1'b0;
    end

    cmd_send_hold <= cmd_state == STA_CMD_SEND ? 1'b1 : 1'b0;
end

always@(posedge clk) begin
    if(reset) begin
        cmd_send_cnt <= 6'd0;
    end
    else if(cmd_send_hold && cmd_send_flag && cmd_send_cnt == 6'd48) begin
        cmd_send_cnt <= 6'd0;
    end
    else if(cmd_send_hold && cmd_send_flag) begin
        cmd_send_cnt <= cmd_send_cnt + 1'b1;
    end
end

always@(posedge clk) begin
    if(reset) begin
        cmd_send_shift_data <= 40'h0;
    end
    else if(cmd_send_flag) begin
        cmd_send_shift_data <= {cmd_send_shift_data[38:0],1'b1};
    end
    else if(sd_cmd_tx_ack) begin
        cmd_send_shift_data <= {1'b0,1'b1,sd_cmd_tx_nub,sd_cmd_tx_data};
    end
end

always@(posedge clk) begin
    if(reset) begin
        sd_sdio_cmd_send_data <= 1'b1;
    end
    else if(cmd_send_cnt <= 6'd39 && cmd_send_flag) begin
        sd_sdio_cmd_send_data <= cmd_send_shift_data[39];
    end
    else if(cmd_send_cnt <= 6'd46 && cmd_send_flag) begin
        sd_sdio_cmd_send_data <= cmd_send_crc[6];
    end
    else if(cmd_send_cnt <= 6'd47 && cmd_send_flag) begin
        sd_sdio_cmd_send_data <= 1'b1;
    end
    else if(cmd_pre_hold) begin
        sd_sdio_cmd_send_data <= 1'b1;
    end
end

always@(posedge clk) begin
    if(reset) begin
        cmd_send_crc <= 7'h0;
    end
    else if(cmd_pre_hold) begin
        cmd_send_crc <= 7'h0;
    end
    else if(cmd_send_cnt <= 6'd39 && cmd_send_flag) begin
        cmd_send_crc <= CalcCrc7(cmd_send_crc, cmd_send_shift_data[39]);
    end
    else if(cmd_send_cnt > 6'd39 && cmd_send_cnt <= 6'd46 && cmd_send_flag) begin
        cmd_send_crc <= {cmd_send_crc[5:0],1'b1};
    end
end

/*----------------------------------------------------------*/

always@(posedge clk) begin
    if(reset) begin
        cmd_rp_type     <= 3'h0;
        cmd_rp_bit_nub  <= 8'd0;
    end
    else if(sd_cmd_tx_ack && (sd_cmd_tx_nub == 6'd7 || sd_cmd_tx_nub == 6'd12)) begin
        cmd_rp_type     <= 3'h0;    //R1b : CMD7 , CMD12
        cmd_rp_bit_nub  <= 8'd48;
    end
    else if(sd_cmd_tx_ack && (sd_cmd_tx_nub == 6'd6 || sd_cmd_tx_nub == 6'd55 || sd_cmd_tx_nub == 6'd17 || sd_cmd_tx_nub == 6'd18 || sd_cmd_tx_nub == 6'd24 || sd_cmd_tx_nub == 6'd25)) begin
        cmd_rp_type     <= 3'h1;    //R1 : ACMD6 , CMD55 , CMD17 , CMD18 , CMD24 , CMD25
        cmd_rp_bit_nub  <= 8'd48;
    end
    else if(sd_cmd_tx_ack && (sd_cmd_tx_nub == 6'd2)) begin
        cmd_rp_type     <= 3'h2;    //R2 : CMD2
        cmd_rp_bit_nub  <= 8'd136;
    end
    else if(sd_cmd_tx_ack && (sd_cmd_tx_nub == 6'd41)) begin
        cmd_rp_type     <= 3'h3;    //R3 : ACMD41
        cmd_rp_bit_nub  <= 8'd48;
    end
    else if(sd_cmd_tx_ack && (sd_cmd_tx_nub == 6'd3)) begin
        cmd_rp_type     <= 3'h6;    //R6 : CMD3
        cmd_rp_bit_nub  <= 8'd48;
    end
    else if(sd_cmd_tx_ack && (sd_cmd_tx_nub == 6'd8)) begin
        cmd_rp_type     <= 3'h7;    //R7 : CMD8
        cmd_rp_bit_nub  <= 8'd48;
    end
end

/*----------------------------------------------------------*/

always@(posedge clk) begin
    cmd_rp_rcv_flag <= sd_sdio_clk_pos;
end

always@(posedge clk) begin
    if(sd_sdio_clk_pos && (cmd_state == STA_CMD_WAIT || cmd_state == STA_CMD_RP_RCV)) begin
        cmd_rp_rcv_data <= SD_SDIO_CMD;
    end
    else if(sd_sdio_clk_pos) begin
        cmd_rp_rcv_data <= 1'b1;
    end
end

assign cmd_rp_rcv_start = cmd_state == STA_CMD_WAIT && cmd_rp_rcv_flag && cmd_rp_rcv_data == 1'b0;

always@(posedge clk) begin
    if(cmd_rp_rcv_cnt == cmd_rp_bit_nub - 1'b1 && cmd_rp_rcv_flag) begin
        cmd_rp_rcv_hold <= 1'b0;
    end
    else if(cmd_rp_rcv_start) begin
        cmd_rp_rcv_hold <= 1'b1;
    end
end

always@(posedge clk) begin
    if(reset) begin
        cmd_rp_rcv_cnt <= 8'd0;
    end
    else if(cmd_pre_hold || cmd_rp_rcv_end) begin
        cmd_rp_rcv_cnt <= 8'd0;
    end
    else if(cmd_rp_rcv_start) begin
        cmd_rp_rcv_cnt <= cmd_rp_rcv_cnt + 1'b1;
    end
    else if(cmd_rp_rcv_hold && cmd_rp_rcv_flag) begin
        cmd_rp_rcv_cnt <= cmd_rp_rcv_cnt + 1'b1;
    end
end

always@(posedge clk) begin
    if(cmd_rp_rcv_start) begin
        cmd_rp_rcv_shift <= 128'h0;
    end
    else if(cmd_rp_rcv_hold && cmd_rp_rcv_flag) begin
        cmd_rp_rcv_shift <= {cmd_rp_rcv_shift[134:0],cmd_rp_rcv_data};
    end
end

always@(posedge clk) begin
    if(reset) begin
        cmd_rp_rcv_crc7 <= 7'h0;
    end
    else if(cmd_pre_hold) begin
        cmd_rp_rcv_crc7 <= 7'h0;
    end
    else if(cmd_rp_type != 3'd2 && cmd_rp_rcv_start) begin
        cmd_rp_rcv_crc7 <= CalcCrc7(cmd_rp_rcv_crc7, 1'b0);
    end
    else if(cmd_rp_type != 3'd2 && cmd_rp_rcv_hold && cmd_rp_rcv_flag && (cmd_rp_rcv_cnt < cmd_rp_bit_nub - 1'b1)) begin
        cmd_rp_rcv_crc7 <= CalcCrc7(cmd_rp_rcv_crc7, cmd_rp_rcv_data);
    end
    else if(cmd_rp_type == 3'd2 && cmd_rp_rcv_hold && cmd_rp_rcv_flag && (cmd_rp_rcv_cnt < cmd_rp_bit_nub - 1'b1 && cmd_rp_rcv_cnt > 8'd8)) begin
        cmd_rp_rcv_crc7 <= CalcCrc7(cmd_rp_rcv_crc7, cmd_rp_rcv_data);
    end
end

always@(posedge clk) begin
    if(sd_cmd_rp_ack) begin
        cmd_rp_rcv_crc7_err_hold <= 1'b0;
    end
    else if(cmd_rp_rcv_hold && cmd_rp_rcv_flag && cmd_rp_rcv_cnt == cmd_rp_bit_nub - 1'b1) begin
        cmd_rp_rcv_crc7_err_hold <= cmd_rp_rcv_crc7 == 7'h0 ? 1'b0 : 1'b1;
    end
end

always@(posedge clk) begin
    if(cmd_state == STA_CMD_RP_RCV && cmd_rp_type == 3'd0 && cmd_rp_rcv_R1b_busy_cnt == R1B_BUSY_END_NUB && cmd_rp_rcv_cnt == cmd_rp_bit_nub && cmd_rp_rcv_flag) begin
        cmd_rp_rcv_end <= 1'b1;
    end
    else if(cmd_state == STA_CMD_RP_RCV && cmd_rp_type != 3'd0 && cmd_rp_rcv_cnt == cmd_rp_bit_nub && cmd_rp_rcv_flag) begin
        cmd_rp_rcv_end <= 1'b1;
    end
    else begin
        cmd_rp_rcv_end <= 1'b0;
    end
end

always@(posedge clk) begin

    sd_cmd_rp_ack   <= cmd_state == STA_CMD_DONE && cmd_rp_nrp_sel ? 1'b1 : 1'b0;

    if(cmd_rp_rcv_end) begin
        sd_cmd_rp_type      <= cmd_rp_type;
        sd_cmd_rp_data_Rx   <= cmd_rp_rcv_shift[39:8];
        sd_cmd_rp_data_R2   <= cmd_rp_rcv_shift[127:8];
    end
    
    if(cmd_state == STA_CMD_DONE && cmd_rp_type != 3'd3 && cmd_rp_rcv_crc7_err_hold) begin
        sd_cmd_rp_err <= 1'b1;
    end
    else begin
        sd_cmd_rp_err <= 1'b0;
    end
end


always@(posedge clk) begin
    if(reset) begin
        cmd_rp_rcv_R1b_busy_cnt <= 8'd0;
    end
    else if(cmd_rp_rcv_end) begin
        cmd_rp_rcv_R1b_busy_cnt <= 8'd0;
    end
    else if(cmd_state == STA_CMD_RP_RCV && cmd_rp_type == 3'd0 && cmd_rp_rcv_flag && SD_SDIO_DATA[0] == 1'b0 && cmd_rp_rcv_cnt == cmd_rp_bit_nub) begin
        cmd_rp_rcv_R1b_busy_cnt <= 8'd0;
    end
    else if(cmd_state == STA_CMD_RP_RCV && cmd_rp_type == 3'd0 && cmd_rp_rcv_flag && SD_SDIO_DATA[0] == 1'b1 && cmd_rp_rcv_cnt == cmd_rp_bit_nub) begin
        cmd_rp_rcv_R1b_busy_cnt <= cmd_rp_rcv_R1b_busy_cnt + 1'b1;
    end
end

//Timeout mechanism
always@(posedge clk) begin
    if(cmd_state == STA_CMD_WAIT) begin
        cmd_rp_time_cnt <= cmd_rp_time_cnt + 1'b1;
    end
    else if(cmd_state == STA_CMD_RP_RCV) begin
        cmd_rp_time_cnt <= cmd_rp_time_cnt + 1'b1;
    end
    else begin
        cmd_rp_time_cnt <= 28'd0;
    end

    sd_cmd_rp_timeout <= cmd_rp_time_cnt == CLK_FREQ - 1'b1 ? 1'b1 : 1'b0;
end

/*----------------------------------------------------------*/

always@(posedge clk) begin
    if(reset) begin
        read_state <= STA_READ_IDLE;
    end
    else begin
        case(read_state)
            STA_READ_IDLE   : begin if(cmd_send_flag && cmd_send_cnt == 6'd48 && cmd_rp_nrp_sel == 1'b1)    begin read_state <= STA_READ_WAIT   ;end end
            STA_READ_WAIT   : begin if(read_start)                                                          begin read_state <= STA_READ_RCV    ;end end
            STA_READ_RCV    : begin if(read_end)                                                            begin read_state <= STA_READ_DONE   ;end end
            STA_READ_DONE   : begin read_state <= STA_READ_IDLE   ;end
            default         : begin read_state <= STA_READ_IDLE   ;end
        endcase
    end
end

always@(posedge clk) begin
    read_flag <= sd_sdio_clk_pos;
end

always@(posedge clk) begin
    if(sd_sdio_clk_pos && (read_state == STA_READ_WAIT || read_state == STA_READ_RCV)) begin
        read_data <= SD_SDIO_DATA;
    end
    else if(sd_sdio_clk_pos) begin
        read_data <= 4'hF;
    end
end

assign read_start = read_state == STA_READ_WAIT && read_flag && read_data == 4'h0;

always@(posedge clk) begin
    if(read_cnt == READ_CNT_END_NUB && read_flag) begin
        read_hold <= 1'b0;
    end
    else if(read_start) begin
        read_hold <= 1'b1;
    end
end

always@(posedge clk) begin
    if(reset) begin
        read_cnt <= 8'd0;
    end
    else if(read_start || read_end) begin
        read_cnt <= 8'd0;
    end
    else if(read_hold && read_flag) begin
        read_cnt <= read_cnt + 1'b1;
    end

    read_end <= read_flag && read_hold && read_cnt == READ_CNT_END_NUB ? 1'b1 : 1'b0;
end


always@(posedge clk) begin
    if(read_hold && read_flag && read_cnt[0] == 1'b1 && read_cnt < 11'd1024) begin
        read_shift_dv <= 1'b1;
    end
    else begin
        read_shift_dv <= 1'b0;
    end
end

always@(posedge clk) begin
    if(read_start) begin
        read_shift_data <= 8'h0;
    end
    else if(read_hold && read_flag && read_cnt < 11'd1024) begin
        read_shift_data <= {read_shift_data[3:0],read_data};
    end
end


genvar i;
generate
    for(i = 0;i < 4;i = i + 1) begin : CRC16_CHECKSUM
        always@(posedge clk) begin
            if(read_start) begin
                read_crc16[i] <= 16'h0;
            end
            else if(read_flag && read_hold) begin
                read_crc16[i] <= CalcCrc16(read_crc16[i], read_data[i]);
            end
        end

        always@(posedge clk) begin
            if(read_end && read_crc16[i] != 16'd0) begin
                read_crc16_err[i] <= 1'b1;
            end
            else begin
                read_crc16_err[i] <= 1'b0;
            end
        end
    end
endgenerate

always@(posedge clk) begin

    sd_read_start <= read_start;

    if(read_shift_dv) begin
        sd_read_dv      <= 1'b1;
        sd_read_data    <= read_shift_data;
    end
    else begin
        sd_read_dv      <= 1'b0;
    end

    if(reset) begin
        sd_read_cnt <= 9'd0;
    end
    else if(sd_read_end) begin
        sd_read_cnt <= 9'd0;
    end
    else if(sd_read_dv) begin
        sd_read_cnt <= sd_read_cnt + 1'b1;
    end

    sd_read_crc_err <= read_crc16_err;
    sd_read_end     <= read_state == STA_READ_DONE ? 1'b1 : 1'b0;
end

/*----------------------------------------------------------*/

assign SD_SDIO_CMD = cmd_send_hold | cmd_pre_hold ? sd_sdio_cmd_send_data : 1'bz;

assign SD_SDIO_CLK = sd_sdio_clk_r;

assign SD_SDIO_DATA = 4'bzzzz;

/*----------------------------------------------------------*/

endmodule
