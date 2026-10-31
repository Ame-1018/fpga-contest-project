/************************************************************\
**	Copyright (c) 2012-2026 Anlogic Inc.
**	All Right Reserved.
\************************************************************/
/************************************************************\
**	Gen time	:	Oct 09 2026 18:01:44
**	IpTool version	:	2026.01(189136 2026/01/26)
**	App version	:	6.2.2(build number:190657)
**	Ip Version	:	1.0
\************************************************************/
`timescale 1ns/1ns
module VPI_INIT
(
  input                         clk,
  output  [0:0]                 outprobe0
);

  VPI_VPI_INIT  VPI_Inst
  (
      .clk(clk),
      .outprobe0(outprobe0)
  );
endmodule
