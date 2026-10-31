/************************************************************\
**	Copyright (c) 2012-2026 Anlogic Inc.
**	All Right Reserved.
\************************************************************/
/************************************************************\
**	Gen time	:	Oct 16 2026 16:16:51
**	IpTool version	:	2026.01(189136 2026/01/26)
**	App version	:	6.2.2(build number:190657)
**	Ip Version	:	3.0
\************************************************************/
`timescale 1ns/1ps
module asfifo_audio_data
(
  input                         rst,
  input   [31:0]                di,
  input                         clkr,
  input                         re,
  input                         clkw,
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
  output  [7:0]                 rdusedw,
  output  [7:0]                 wrusedw,
  output                        wr_rst_done,
  output                        rd_rst_done
);

  soft_fifo_asfifo_audio_data
  #(
      .COMMON_CLK_EN(0),
      .MEMORY_TYPE(0),
      .RST_TYPE(1),
      .DATA_WIDTH_W(32),
      .ADDR_WIDTH_W(8),
      .DATA_WIDTH_R(32),
      .ADDR_WIDTH_R(8),
      .DOUT_INITVAL(32'h0),
      .OUTREG_EN("NOREG"),
      .SHOW_AHEAD_EN(0),
      .AL_FULL_NUM(16),
      .AL_EMPTY_NUM(16),
      .RDUSEDW_WIDTH(8),
      .WRUSEDW_WIDTH(8),
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
