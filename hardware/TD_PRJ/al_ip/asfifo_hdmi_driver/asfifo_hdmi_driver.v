/************************************************************\
**	Copyright (c) 2012-2026 Anlogic Inc.
**	All Right Reserved.
\************************************************************/
/************************************************************\
**	Gen time	:	Oct 20 2026 09:00:50
**	IpTool version	:	2026.01(189136 2026/01/26)
**	App version	:	6.2.2(build number:190657)
**	Ip Version	:	3.0
\************************************************************/
`timescale 1ns/1ps
module asfifo_hdmi_driver
(
  input                         rst,
  input   [23:0]                di,
  input                         clkr,
  input                         re,
  input                         clkw,
  input                         we,
  output  [23:0]                dout,
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

  soft_fifo_asfifo_hdmi_driver
  #(
      .COMMON_CLK_EN(0),
      .MEMORY_TYPE(2),
      .RST_TYPE(1),
      .DATA_WIDTH_W(24),
      .ADDR_WIDTH_W(10),
      .DATA_WIDTH_R(24),
      .ADDR_WIDTH_R(10),
      .DOUT_INITVAL(24'h0),
      .OUTREG_EN("NOREG"),
      .SHOW_AHEAD_EN(0),
      .AL_FULL_NUM(3),
      .AL_EMPTY_NUM(3),
      .RDUSEDW_WIDTH(10),
      .WRUSEDW_WIDTH(10),
      .ASYNC_RST_SYNC_RELS(1),
      .SYNC_STAGE(2)
  )soft_fifo_Inst
  (
      .rst(rst),
      .di(di),
      .clkr(clkr),
      .re(re),
      .clkw(clkw),
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
