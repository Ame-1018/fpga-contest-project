/************************************************************\
**	Copyright (c) 2012-2026 Anlogic Inc.
**	All Right Reserved.
\************************************************************/
/************************************************************\
**	Gen time	:	Oct 21 2026 12:39:17
**	IpTool version	:	2026.01(189136 2026/01/26)
**	App version	:	6.2.2(build number:190657)
**	Ip Version	:	3.0
\************************************************************/
`timescale 1ns/1ps
module sfifo_rd_data_buf
(
  input                         rst,
  input   [31:0]                di,
  input                         clk,
  input                         re,
  input                         we,
  output  [31:0]                dout,
  output                        empty_flag,
  output                        aempty,
  output                        full_flag,
  output                        afull,
  output                        valid,
  output                        overflow,
  output                        underflow,
  output                        wr_success,
  output  [9:0]                 rdusedw,
  output  [9:0]                 wrusedw,
  output                        wr_rst_done,
  output                        rd_rst_done
);

  soft_fifo_sfifo_rd_data_buf
  #(
      .COMMON_CLK_EN(1),
      .MEMORY_TYPE(0),
      .RST_TYPE(1),
      .DATA_WIDTH_W(32),
      .ADDR_WIDTH_W(9),
      .DATA_WIDTH_R(32),
      .ADDR_WIDTH_R(9),
      .DOUT_INITVAL(32'h0),
      .OUTREG_EN("OUT_REG"),
      .SHOW_AHEAD_EN(0),
      .AL_FULL_NUM(32),
      .AL_EMPTY_NUM(32),
      .RDUSEDW_WIDTH(10),
      .WRUSEDW_WIDTH(10),
      .ASYNC_RST_SYNC_RELS(1),
      .SYNC_STAGE(2)
  )soft_fifo_Inst
  (
      .rst(rst),
      .di(di),
      .clk(clk),
      .re(re),
      .we(we),
      .dout(dout),
      .empty_flag(empty_flag),
      .aempty(aempty),
      .full_flag(full_flag),
      .afull(afull),
      .valid(valid),
      .overflow(overflow),
      .underflow(underflow),
      .wr_success(wr_success),
      .rdusedw(rdusedw),
      .wrusedw(wrusedw),
      .wr_rst_done(wr_rst_done),
      .rd_rst_done(rd_rst_done)
  );
endmodule
