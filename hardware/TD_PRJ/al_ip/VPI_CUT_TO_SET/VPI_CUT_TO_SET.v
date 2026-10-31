/************************************************************\
**	Copyright (c) 2012-2026 Anlogic Inc.
**	All Right Reserved.
\************************************************************/
/************************************************************\
**	Gen time	:	Oct 20 2026 10:27:25
**	IpTool version	:	2026.01(189136 2026/01/26)
**	App version	:	6.2.2(build number:190657)
**	Ip Version	:	1.0
\************************************************************/
`timescale 1ns/1ns
module VPI_CUT_TO_SET
(
  input                         clk,
  output  [2:0]                 outprobe0,
  output  [1:0]                 outprobe1,
  output  [7:0]                 outprobe2,
  output  [7:0]                 outprobe3,
  output  [7:0]                 outprobe4,
  output  [7:0]                 outprobe5,
  output  [0:0]                 outprobe6,
  output  [0:0]                 outprobe7,
  output  [0:0]                 outprobe8,
  output  [12:0]                outprobe9,
  output  [12:0]                outprobe10,
  output  [12:0]                outprobe11,
  output  [12:0]                outprobe12,
  output  [12:0]                outprobe13,
  output  [1:0]                 outprobe14,
  output  [1:0]                 outprobe15,
  output  [23:0]                outprobe16,
  output  [0:0]                 outprobe17,
  output  [0:0]                 outprobe18,
  output  [1:0]                 outprobe19,
  output  [0:0]                 outprobe20,
  output  [12:0]                outprobe21,
  output  [12:0]                outprobe22
);

  VPI_VPI_CUT_TO_SET  VPI_Inst
  (
      .clk(clk),
      .outprobe0(outprobe0),
      .outprobe1(outprobe1),
      .outprobe2(outprobe2),
      .outprobe3(outprobe3),
      .outprobe4(outprobe4),
      .outprobe5(outprobe5),
      .outprobe6(outprobe6),
      .outprobe7(outprobe7),
      .outprobe8(outprobe8),
      .outprobe9(outprobe9),
      .outprobe10(outprobe10),
      .outprobe11(outprobe11),
      .outprobe12(outprobe12),
      .outprobe13(outprobe13),
      .outprobe14(outprobe14),
      .outprobe15(outprobe15),
      .outprobe16(outprobe16),
      .outprobe17(outprobe17),
      .outprobe18(outprobe18),
      .outprobe19(outprobe19),
      .outprobe20(outprobe20),
      .outprobe21(outprobe21),
      .outprobe22(outprobe22)
  );
endmodule
