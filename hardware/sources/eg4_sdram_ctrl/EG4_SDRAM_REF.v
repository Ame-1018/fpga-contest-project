`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Create Date: 2026/10/08 09:21:17
// Design Name: 
// Module Name: EG4_SDRAM_REF
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

module EG4_SDRAM_REF(
    input   wire                clk                     ,
    input   wire                reset                   ,

    input   wire                sdram_busy              ,

    output  reg                 sdram_ref_req           ,
    input   wire                sdram_ref_ack           ,
    output  wire                sdram_ref_hold          
);

parameter                       CLK_CYCLE               = 8;
parameter                       REF_CYCLE_TIME          = 64_000_000;
parameter                       REF_ROW_TOTAL           = 2**11;

parameter                       SDRAM_REF_CNT_END       = (REF_CYCLE_TIME / REF_ROW_TOTAL) / CLK_CYCLE;

reg     [12:0]                  sdram_ref_cnt           ;

reg                             sdram_ref_time_flag     ;
reg                             sdram_ref_time_hold     ;
reg     [2:0]                   sdram_ref_time_cnt      ;



always@(posedge clk) begin
    if(reset) begin
        sdram_ref_cnt <= 13'd0;
    end
    else if(sdram_ref_cnt == SDRAM_REF_CNT_END - 1'b1) begin
        sdram_ref_cnt <= 13'd0;
    end
    else begin
        sdram_ref_cnt <= sdram_ref_cnt + 1'b1;
    end
end


always@(posedge clk) begin
    sdram_ref_time_flag <= sdram_ref_cnt == SDRAM_REF_CNT_END - 1'b1;
end

always@(posedge clk) begin
    if(reset) begin
        sdram_ref_time_hold <= 1'b0;
    end
    else if(sdram_ref_time_hold && sdram_ref_time_cnt == 3'd7) begin
        sdram_ref_time_hold <= 1'b0;
    end
    else if(sdram_ref_time_flag) begin
        sdram_ref_time_hold <= 1'b1;
    end
end

always@(posedge clk) begin
    if(sdram_ref_req) begin
        sdram_ref_time_cnt <= sdram_ref_time_cnt + 1'b1;
    end
    else begin
        sdram_ref_time_cnt <= 3'd0;
    end
end

always@(posedge clk) begin
    if(reset) begin
        sdram_ref_req <= 1'b0;
    end
    else if(sdram_ref_time_cnt == 3'd7) begin
        sdram_ref_req <= 1'b0;
    end
    else if(sdram_ref_time_hold && !sdram_busy) begin
        sdram_ref_req <= 1'b1;
    end
end

assign sdram_ref_hold = sdram_ref_time_hold;


endmodule
